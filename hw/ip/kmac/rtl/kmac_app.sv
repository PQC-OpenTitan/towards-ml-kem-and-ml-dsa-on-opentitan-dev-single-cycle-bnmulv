// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192)
// Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors
//
// KMAC Application interface

`include "prim_assert.sv"

module kmac_app
  import kmac_pkg::*;
#(
  // App specific configs are defined in kmac_pkg
  parameter  bit EnMasking = 1'b0,
  localparam int Share = (EnMasking) ? 2 : 1, // derived parameter
  parameter  bit SecIdleAcceptSwMsg = 1'b0
) (
  input clk_i,
  input rst_ni,

  // Secret Key from register
  input [MaxKeyLen-1:0] reg_key_data_i [Share],
  input key_len_e       reg_key_len_i,

  // Prefix from register
  input [sha3_pkg::NSRegisterSize*8-1:0] reg_prefix_i,

  // mode, strength, kmac_en from register
  input                             reg_kmac_en_i,
  input sha3_pkg::sha3_mode_e       reg_sha3_mode_i,
  input sha3_pkg::keccak_strength_e reg_keccak_strength_i,

  // Data from Software
  input                sw_valid_i,
  input [MsgWidth-1:0] sw_data_i,
  input [MsgWidth-1:0] sw_mask_i,
  output logic         sw_ready_o,

  // KeyMgr Sideload Key interface
  input keymgr_pkg::hw_key_req_t keymgr_key_i,

  // Application Message in/ Digest out interface + control signals
  input  app_req_t [NumAppIntf-1:0] app_i,
  output app_rsp_t [NumAppIntf-1:0] app_o,

  // to KMAC Core: Secret key
  output logic [MaxKeyLen-1:0] key_data_o [Share],
  output key_len_e             key_len_o,

  // to MSG_FIFO
  output logic                kmac_valid_o,
  output logic [MsgWidth-1:0] kmac_data_o,
  output logic [MsgWidth-1:0] kmac_mask_o,
  input                       kmac_ready_i,

  // KMAC Core
  output logic kmac_en_o,

  // To Sha3 Core
  output logic [sha3_pkg::NSRegisterSize*8-1:0] sha3_prefix_o,
  output sha3_pkg::sha3_mode_e                  sha3_mode_o,
  output sha3_pkg::keccak_strength_e            keccak_strength_o,

  // STATE from SHA3 Core
  input                        keccak_state_valid_i,
  input [sha3_pkg::StateW-1:0] keccak_state_i [Share],

  // to STATE TL-window if Application is not active, the incoming state goes to
  // register if kdf_en is set, the state value goes to application and the
  // output to the register is all zero.
  output logic                        reg_state_valid_o,
  output logic [sha3_pkg::StateW-1:0] reg_state_o [Share],

  // Configurations If key_en is set, the logic uses KeyMgr's sideloaded key as
  // a secret key rather than register values. This only affects when software
  // initiates. If App initiates the hash operation and uses KMAC algorithm, it
  // always uses sideloaded key.
  input keymgr_key_en_i,

  // Commands
  // Command from software
  input kmac_cmd_e sw_cmd_i,

  // from SHA3
  input prim_mubi_pkg::mubi4_t absorbed_i,
  input prim_mubi_pkg::mubi4_t squeezing_i,

  // to KMAC
  output kmac_cmd_e cmd_o,

  // to SW
  output prim_mubi_pkg::mubi4_t absorbed_o,

  // To status
  output logic app_active_o,

  // Status
  // - entropy_ready_i: Entropy configured by SW. It is used to check if App
  //                    is OK to request.
  input prim_mubi_pkg::mubi4_t entropy_ready_i,

  // Error input
  // This error comes from KMAC/SHA3 engine.
  // KeyMgr interface delivers the error signal to KeyMgr to drop the current op
  // and re-initiate.
  // If error happens, regardless of SW-initiated or KeyMgr-initiated, the error
  // is reported to the ERR_CODE so that SW can look into.
  input error_i,

  // SW sets err_processed bit in CTRL then the logic goes to Idle
  input err_processed_i,

  // error_o value is pushed to Error FIFO at KMAC/SHA3 top and reported to SW
  output kmac_pkg::err_t error_o,

  // Life cycle
  input  lc_ctrl_pkg::lc_tx_t lc_escalate_en_i,

  output logic sparse_fsm_error_o
);

  import sha3_pkg::KeccakBitCapacity;
  import sha3_pkg::L128;
  import sha3_pkg::L224;
  import sha3_pkg::L256;
  import sha3_pkg::L384;
  import sha3_pkg::L512;

  /////////////////
  // Definitions //
  /////////////////

  // Digest width is same to the key width `keymgr_pkg::KeyWidth`.
  localparam int KeyMgrKeyW = $bits(keymgr_key_i.key[0]);

  localparam key_len_e KeyLengths [5] = '{Key128, Key192, Key256, Key384, Key512};

  localparam int SelKeySize = (AppKeyW == 128) ? 0 :
                              (AppKeyW == 192) ? 1 :
                              (AppKeyW == 256) ? 2 :
                              (AppKeyW == 384) ? 3 :
                              (AppKeyW == 512) ? 4 : 0 ;
  localparam int SelDigSize = (AppDigestW == 128) ? 0 :
                              (AppDigestW == 192) ? 1 :
                              (AppDigestW == 256) ? 2 :
                              (AppDigestW == 384) ? 3 :
                              (AppDigestW == 512) ? 4 : 0 ;
  localparam key_len_e SideloadedKey = KeyLengths[SelKeySize];

  // Define right_encode(outlen) value here
  // Look at kmac_pkg::key_len_e for the kinds of key size
  //
  // These values should be exactly the same as the key length encodings
  // in kmac_core.sv, with the only difference being that the byte representing
  // the byte-length of the encoded value is in the MSB position due to right encoding
  // instead of in the LSB position (left encoding).
  localparam int OutLenW = 24;
  localparam logic [OutLenW-1:0] EncodedOutLen [5]= '{
    24'h 0001_80, // Key128
    24'h 0001_C0, // Key192
    24'h 02_0001, // Key256
    24'h 02_8001, // Key384
    24'h 02_0002  // Key512
  };

  localparam logic [OutLenW-1:0] EncodedOutLenMask [5] = '{
    24'h 00FFFF, // Key128,
    24'h 00FFFF, // Key192
    24'h FFFFFF, // Key256
    24'h FFFFFF, // Key384
    24'h FFFFFF  // Key512
  };

  // TODO: regenerate
  localparam int StateWidth = 11;                                    
  typedef enum logic [StateWidth-1:0] {                  
    StIdle                  = 11'b00010100000,                           
    StAppCfg                = 11'b00010111110,                           
    StAppDynamicCfg         = 11'b10110011110,                           
    StAppMsg                = 11'b10100011101,                           
    StAppOutLen             = 11'b10001001101,                           
    StAppProcess            = 11'b00100101101,                           
    StAppManualRun          = 11'b01111111110,                           
    StAppWait               = 11'b10011101000,                           
    StAppShiftDigest        = 11'b10011101001,                           
    StSw                    = 11'b11010111011,                           
    StKeyMgrErrKeyNotValid  = 11'b01011100111,                           
    StError                 = 11'b10011001110,                           
    StServiceRejectedError  = 11'b10101000100,                                                                                  
    StTerminalError         = 11'b00100010010                            
  } st_e;                                                                                                     
                                                                                                                        
  /////////////
  // Signals //
  /////////////

  st_e st, st_d;

  // app_rsp_t signals
  // The state machine controls mux selection, which controls the ready signal
  // the other responses are controled in separate logic. So define the signals
  // here and merge them to the response.
  logic app_data_ready, fsm_data_ready;
  logic app_digest_done, sha3_digest_done, fsm_digest_done_q, fsm_digest_done_d;
  logic [AppDigestW-1:0] app_digest [2];

  // One more slot for value NumAppIntf. It is the value when no app intf is
  // chosen.
  localparam int unsigned AppIdxW = $clog2(NumAppIntf);

  // app_id indicates, which app interface was chosen. various logic use this
  // value to get the config or return the data.
  logic [AppIdxW-1:0] app_id, app_id_d;
  logic               clr_appid, set_appid;

  logic                       set_dynamic_sha_mode;
  sha3_pkg::sha3_mode_e       dynamic_sha3_mode_q;
  sha3_pkg::keccak_strength_e dynamic_keccak_strength_q;
  logic [2:0] max_digest_words;
  logic next_digest_word;
  logic reset_digest_word;
  logic digest_valid;
  logic pack_digest_word;
  logic shift_and_pack_digest;
  logic [2:0] digest_word_idx_q, digest_word_idx_d;

  // Output length
  logic [OutLenW-1:0] encoded_outlen, encoded_outlen_mask;

  // state output
  // Mux selection signal
  app_mux_sel_e mux_sel;
  app_mux_sel_e mux_sel_buf_output;
  app_mux_sel_e mux_sel_buf_err_check;
  app_mux_sel_e mux_sel_buf_kmac;

  // Error checking logic

  kmac_pkg::err_t fsm_err, mux_err;

  logic service_rejected_error;
  logic service_rejected_error_set, service_rejected_error_clr;

  // Digest packer for OTBN app intf 
  logic [255:0] digest_word;
  logic [255:0] packed_digest_word;
  logic packed_digest_word_valid;
  logic digest_packer_ready;
  logic digest_packer_error;
  logic req_packed_digest_word;
  logic [255:0] digest_word_mask;
  logic [1:0] permutation_ctr;
  logic incr_permutation_ctr, reset_permutation_ctr;
  logic otbn_app_intf_done;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)                         service_rejected_error <= 1'b 0;
    else if (service_rejected_error_set) service_rejected_error <= 1'b 1;
    else if (service_rejected_error_clr) service_rejected_error <= 1'b 0;
  end

  ////////////////////////////
  // Application Mux/ Demux //
  ////////////////////////////

  always_ff @(posedge clk_i) begin
    if (app_i[3].valid && set_appid) begin
      dynamic_sha3_mode_q <= sha3_pkg::sha3_mode_e'(app_i[3].data[1:0]);
      dynamic_keccak_strength_q <= sha3_pkg::keccak_strength_e'(app_i[3].data[4:2]);
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      permutation_ctr <= 2'h0;
    end else if (reset_permutation_ctr || clr_appid) begin
      permutation_ctr <= 2'h0;
    end else if (incr_permutation_ctr) begin
      permutation_ctr <= permutation_ctr + 1;
    end 
  end

  assign digest_word_idx_d = digest_word_idx_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) digest_word_idx_q <= 3'h0;
    else if ((app_i[3].valid && set_appid) || reset_digest_word) digest_word_idx_q <= 3'h0;
    else if (next_digest_word) digest_word_idx_q <= digest_word_idx_d + 3'h1;
  end

  // Processing return data.
  // sends to only selected app intf.
  // clear digest right after done to not leak info to other interface
  always_comb begin
    for (int unsigned i = 0 ; i < NumAppIntf - 1; i++) begin
      if (i == app_id) begin
        app_o[i] = '{
          ready:         app_data_ready  | fsm_data_ready,
          done:          app_digest_done | fsm_digest_done_q,
          digest_share0: app_digest[0],
          digest_share1: app_digest[1],
          // if fsm asserts done, should be an error case.
          error:         error_i | fsm_digest_done_q | sparse_fsm_error_o
                         | service_rejected_error
        };
      end else begin
        app_o[i] = '{
          ready: 1'b 0,
          done:  1'b 0,
          digest_share0: '0,
          digest_share1: '0,
          error: 1'b 0
        };
      end
    end // for {i, NumAppIntf, i++}
  end // always_comb
  
  // Special case OTBN app intf
  always_comb begin
    if (app_id == 3) begin
      app_o[3] = '{
        ready:         app_data_ready  | fsm_data_ready,
        done:          otbn_app_intf_done,
        digest_share0: {128'h0, packed_digest_word},
        digest_share1: 384'h0,
        error:         error_i | fsm_digest_done_q | sparse_fsm_error_o
                       | service_rejected_error
      };
    end else begin
      app_o[3] = '{
        ready: 1'b 0,
        done:  1'b 0,
        digest_share0: '0,
        digest_share1: '0,
        error: 1'b 0
      };
    end
  end

  // app_id latch
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) app_id <= AppIdxW'(0) ; // Do not select any
    else if (clr_appid) app_id <= AppIdxW'(0);
    else if (set_appid) app_id <= app_id_d;
  end

  // app_id selection as of now, app_id uses Priority. The assumption is that
  //  the request normally does not collide. (ROM_CTRL activates very early
  //  stage at the boot sequence)
  //
  //  If this assumption is not true, consider RR arbiter.

  // Prep for arbiter
  logic [NumAppIntf-1:0] app_reqs;
  logic [NumAppIntf-1:0] unused_app_gnts;
  logic [$clog2(NumAppIntf)-1:0] arb_idx;
  logic arb_valid;
  logic arb_ready;

  always_comb begin
    app_reqs = '0;
    for (int unsigned i = 0 ; i < NumAppIntf ; i++) begin
      app_reqs[i] = app_i[i].valid;
    end
  end

  prim_arbiter_fixed #(
    .N (NumAppIntf),
    .DW(1),
    .EnDataPort(1'b 0)
  ) u_appid_arb (
    .clk_i,
    .rst_ni,

    .req_i  (app_reqs),
    .data_i ('{default:'0}),
    .gnt_o  (unused_app_gnts),
    .idx_o  (arb_idx),

    .valid_o (arb_valid),
    .data_o  (), // not used
    .ready_i (arb_ready)
  );

  assign app_id_d = AppIdxW'(arb_idx);
  assign arb_ready = set_appid;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) fsm_digest_done_q <= 1'b 0;
    else         fsm_digest_done_q <= fsm_digest_done_d;
  end

  /////////
  // FSM //
  /////////

  // State register
  `PRIM_FLOP_SPARSE_FSM(u_state_regs, st_d, st, st_e, StIdle)

  // Create a lint error to reduce the risk of accidentally enabling this feature.
  `ASSERT_STATIC_LINT_ERROR(KmacSecIdleAcceptSwMsgNonDefault, SecIdleAcceptSwMsg == 0)

  // Next State & output logic
  // SEC_CM: FSM.SPARSE
  always_comb begin
    st_d = st;

    mux_sel = SecIdleAcceptSwMsg ? SelSw : SelNone;

    // app_id control
    set_appid = 1'b 0;
    clr_appid = 1'b 0;
    set_dynamic_sha_mode = 1'b 0;

    // Commands
    cmd_o = CmdNone;

    // Software output
    absorbed_o = prim_mubi_pkg::MuBi4False;

    // Error
    fsm_err = '{valid: 1'b 0, code: ErrNone, info: '0};
    sparse_fsm_error_o = 1'b 0;

    service_rejected_error_set = 1'b 0;
    service_rejected_error_clr = 1'b 0;

    // If error happens, FSM asserts data ready but discard incoming msg
    fsm_data_ready = 1'b 0;
    fsm_digest_done_d = 1'b 0;

    // digest word control
    next_digest_word = 1'b 0;
    shift_and_pack_digest = 1'b 0;
    reset_digest_word = 1'b 0;
    digest_valid = 1'b 0;
    incr_permutation_ctr = 1'b 0;
    reset_permutation_ctr = 1'b 0;

    unique case (st)
      StIdle: begin
        if (arb_valid) begin
          st_d = StAppCfg;

          // choose app_id
          set_appid = 1'b 1;
        end else if (sw_cmd_i == CmdStart) begin
          st_d = StSw;
          // Software initiates the sequence
          cmd_o = CmdStart;
        end else begin
          st_d = StIdle;
        end
      end

      StAppCfg: begin
        if (AppCfg[app_id].Mode == AppKMAC &&
          prim_mubi_pkg::mubi4_test_false_strict(entropy_ready_i)) begin
          // Check if the entropy is not configured but it is needed in
          // `AppCfg[app_id]` (KMAC mode).
          //
          // SW is not properly configured, report and not request Hashing
          // Return the app with errors
          st_d = StError;

          service_rejected_error_set = 1'b 1;

        end else if ((AppCfg[app_id].Mode == AppKMAC) &&
          !keymgr_key_i.valid) begin
          st_d = StKeyMgrErrKeyNotValid;

          // As mux_sel is not set to SelApp, app_data_ready is still 0.
          // This logic won't accept the requests from the selected App.

        end else if ((AppCfg[app_id].Mode == AppConfigDynamic)) begin

          st_d = StAppDynamicCfg;
          set_dynamic_sha_mode = 1'b 1;
          //set_dynamic_sha_mode = 1'b 1;
          //st_d = StAppMsg;
          //cmd_o = CmdStart;

        end else begin
          // As Cfg is stable now, it sends cmd
          st_d = StAppMsg;

          // App initiates the data
          cmd_o = CmdStart;
        end
      end

      StAppDynamicCfg: begin
        cmd_o = CmdStart;
        st_d = StAppMsg;
        mux_sel = SelDynamicAppCfg;
      end

      StAppMsg: begin
        mux_sel = SelApp;
        if (app_i[app_id].valid && app_o[app_id].ready && app_i[app_id].last) begin
          if (AppCfg[app_id].Mode == AppKMAC) begin
            st_d = StAppOutLen;
          end else begin
            st_d = StAppProcess;
          end
        end else begin
          st_d = StAppMsg;
        end
      end

      StAppOutLen: begin
        mux_sel = SelOutLen;

        if (kmac_valid_o && kmac_ready_i) begin
          st_d = StAppProcess;
        end else begin
          st_d = StAppOutLen;
        end
      end

      StAppProcess: begin
        cmd_o = CmdProcess;
        st_d = StAppWait;
      end

      StAppShiftDigest: begin
        st_d = StAppShiftDigest;
        if (digest_packer_ready) begin
          shift_and_pack_digest = 1'b 1;
          if (digest_word_idx_q == max_digest_words && permutation_ctr == 2'h3) begin
            // We can handle one more squeeze with the remaining bits from previous
            // permutations
            st_d = StAppWait;
          end else if (digest_word_idx_q == max_digest_words) begin
            // We need a new permutation since we only squeezed 64-bit which is not
            // enough to fill 256-bit in the packer.
            st_d = StAppManualRun;
            incr_permutation_ctr = 1'b 1;
          end else begin
            // We can squeeze 256-bit the next time, so we wait for the next squeeze.
            st_d = StAppWait;
          end
        end
      end

      StAppManualRun: begin
        reset_digest_word = 1'b 1;
        cmd_o = CmdManualRun;
        st_d  = StAppWait;
      end

      StAppWait: begin
        if (prim_mubi_pkg::mubi4_test_true_strict(absorbed_i) || prim_mubi_pkg::mubi4_test_true_strict(squeezing_i)) begin
          digest_valid = 1'b 1;
          if (app_i[app_id].hold == 1'b0) begin
            // Send digest to KeyMgr and complete the op
            st_d = StIdle;
            cmd_o = CmdDone;
            clr_appid = 1'b 1;
          end else begin
            if (app_i[app_id].next == 1'b1) begin
              if (digest_word_idx_q < max_digest_words || permutation_ctr < 2'h3) begin
                // We can still squeeze bits from the digest. For SHAKE 128 / 256 either
                // the full 256-bit or 64-bit. StAppShiftDigest will decide if we need
                // further bits (and therefore a new permutation) or not.
                st_d = StAppShiftDigest;
                next_digest_word = 1'b 1;
              end else if (digest_word_idx_q == max_digest_words && permutation_ctr == 2'h3) begin
                // We were able to handle the last squeeze only with remaining bits from the
                // previous permutations (for SHAKE 128 / 256 this is the case for every 4th
                // permutation. Therefore we can squeeze no bits at all and we need to start
                // a new permutation.
                st_d = StAppManualRun;
                reset_permutation_ctr = 1'b 1;
              end
            end else begin
              st_d = StAppWait;
            end
          end
        end else begin
          st_d = StAppWait;
        end
      end

      StSw: begin
        mux_sel = SelSw;

        cmd_o = sw_cmd_i;
        absorbed_o = absorbed_i;

        if (sw_cmd_i == CmdDone) begin
          st_d = StIdle;
        end else begin
          st_d = StSw;
        end
      end

      StKeyMgrErrKeyNotValid: begin
        st_d = StError;

        // As mux_sel is not set to SelApp, app_data_ready is still 0.
        // This logic won't accept the requests from the selected App.
        fsm_err.valid = 1'b 1;
        fsm_err.code = ErrKeyNotValid;
        fsm_err.info = 24'(app_id);
      end

      StError: begin
        // In this state, the state machine flush out the request
        st_d = StError;

        fsm_data_ready = 1'b 1;

        if (err_processed_i) begin
          st_d = StIdle;

          // clear internal variables
          clr_appid = 1'b 1;
        end

        if (app_i[app_id].valid && app_i[app_id].last) begin
          // Send garbage digest to the app interface to complete transaction
          fsm_digest_done_d = 1'b 1;

          if (service_rejected_error) begin
            // If service was rejected, it is assumed the SW is not loaded
            // yet. In this case, return the request with error and keep
            // moving, hoping SW may handle the errors later
            st_d = StServiceRejectedError;
          end
        end

      end

      StServiceRejectedError: begin
        // Clear the error and move to Idle
        // At this state, the app responses the request with an error.
        st_d = StIdle;

        clr_appid = 1'b 1;
        service_rejected_error_clr = 1'b 1;
      end

      StTerminalError: begin
        // this state is terminal
        st_d = st;
        sparse_fsm_error_o = 1'b 1;
        fsm_err.valid = 1'b 1;
        fsm_err.code = ErrFatalError;
        fsm_err.info = 24'(app_id);
      end

      default: begin
        st_d = StTerminalError;
        sparse_fsm_error_o = 1'b 1;
      end
    endcase

    // SEC_CM: FSM.GLOBAL_ESC, FSM.LOCAL_ESC
    // Unconditionally jump into the terminal error state
    // if the life cycle controller triggers an escalation.
    if (lc_ctrl_pkg::lc_tx_test_true_loose(lc_escalate_en_i)) begin
      st_d = StTerminalError;
    end
  end

  //////////////
  // Datapath //
  //////////////

  // Encoded output length
  assign encoded_outlen      = EncodedOutLen[SelDigSize];
  assign encoded_outlen_mask = EncodedOutLenMask[SelKeySize];

  // Data mux
  // This is the main part of the KeyMgr interface logic.
  // The FSM selects KeyMgr interface in a cycle after it receives the first
  // valid data from KeyMgr. The ready signal to the KeyMgr data interface
  // represents the MSG_FIFO ready, only when it is in StKeyMgrMsg state.
  // After KeyMgr sends last beat, the kmac interface (to MSG_FIFO) is switched
  // to OutLen. OutLen is pre-defined values. See `EncodeOutLen` parameter above.
  always_comb begin
    app_data_ready = 1'b 0;
    sw_ready_o = 1'b 1;

    kmac_valid_o = 1'b 0;
    kmac_data_o = '0;
    kmac_mask_o = '0;

    unique case (mux_sel_buf_kmac)
      SelApp: begin
        // app_id is valid at this time
        kmac_valid_o = app_i[app_id].valid;
        kmac_data_o  = app_i[app_id].data;
        // Expand strb to bits. prim_packer inside MSG_FIFO accepts the bit masks
        for (int i = 0 ; i < $bits(app_i[app_id].strb) ; i++) begin
          kmac_mask_o[8*i+:8] = {8{app_i[app_id].strb[i]}};
        end
        app_data_ready = kmac_ready_i;
      end

      SelOutLen: begin
        // Write encoded output length value
        kmac_valid_o = 1'b 1; // always write
        kmac_data_o  = MsgWidth'(encoded_outlen);
        kmac_mask_o  = MsgWidth'(encoded_outlen_mask);
      end

      SelSw: begin
        kmac_valid_o = sw_valid_i;
        kmac_data_o  = sw_data_i ;
        kmac_mask_o  = sw_mask_i ;
        sw_ready_o   = kmac_ready_i ;
      end

      SelDynamicAppCfg: begin
        // Ready to consume next word on app iface,
        // since the first word sets only the config
        app_data_ready = 1'b1;
      end

      default: begin // Incl. SelNone
        kmac_valid_o = 1'b 0;
        kmac_data_o = '0;
        kmac_mask_o = '0;
      end

    endcase
  end

  // Error checking for Mux
  always_comb begin
    mux_err = '{valid: 1'b 0, code: ErrNone, info: '0};

    if (mux_sel_buf_err_check != SelSw && sw_valid_i) begin
      // If SW writes message into FIFO
      mux_err = '{
        valid: 1'b 1,
        code: ErrSwPushedMsgFifo,
        info: 24'({8'h 00, 8'(st), 8'(mux_sel_buf_err_check)})
      };
    end else if (app_active_o && sw_cmd_i != CmdNone) begin
      // If SW issues command except start
      mux_err = '{
        valid: 1'b 1,
        code: ErrSwIssuedCmdInAppActive,
        info: 24'(sw_cmd_i)
      };
    end
  end

  logic [AppMuxWidth-1:0] mux_sel_buf_output_logic;
  assign mux_sel_buf_output = app_mux_sel_e'(mux_sel_buf_output_logic);

  // SEC_CM: LOGIC.INTEGRITY
  prim_sec_anchor_buf #(
   .Width(AppMuxWidth)
  ) u_prim_buf_state_output_sel (
    .in_i(mux_sel),
    .out_o(mux_sel_buf_output_logic)
  );

  logic [AppMuxWidth-1:0] mux_sel_buf_err_check_logic;
  assign mux_sel_buf_err_check = app_mux_sel_e'(mux_sel_buf_err_check_logic);

  // SEC_CM: LOGIC.INTEGRITY
  prim_sec_anchor_buf #(
   .Width(AppMuxWidth)
  ) u_prim_buf_state_err_check (
    .in_i(mux_sel),
    .out_o(mux_sel_buf_err_check_logic)
  );

  logic [AppMuxWidth-1:0] mux_sel_buf_kmac_logic;
  assign mux_sel_buf_kmac = app_mux_sel_e'(mux_sel_buf_kmac_logic);

  // SEC_CM: LOGIC.INTEGRITY
  prim_sec_anchor_buf #(
   .Width(AppMuxWidth)
  ) u_prim_buf_state_kmac_sel (
    .in_i(mux_sel),
    .out_o(mux_sel_buf_kmac_logic)
  );

  // SEC_CM: LOGIC.INTEGRITY
  logic reg_state_valid;
  prim_sec_anchor_buf #(
   .Width(1)
  ) u_prim_buf_state_output_valid (
    .in_i(reg_state_valid),
    .out_o(reg_state_valid_o)
  );

  // Keccak state Demux
  // Keccak state --> Register output is enabled when state is in StSw
  always_comb begin
    reg_state_valid = 1'b 0;
    reg_state_o = '{default:'0};
    if ((mux_sel_buf_output == SelSw) &&
         lc_ctrl_pkg::lc_tx_test_false_strict(lc_escalate_en_i)) begin
      reg_state_valid = keccak_state_valid_i;
      reg_state_o = keccak_state_i;
      // If key is sideloaded and KMAC is SW initiated
      // hide the capacity from SW by zeroing (see #17508)
      if (keymgr_key_en_i) begin
        for (int i = 0; i < Share; i++) begin
          unique case (reg_keccak_strength_i)
            L128: reg_state_o[i][sha3_pkg::StateW-1-:KeccakBitCapacity[L128]] = '0;
            L224: reg_state_o[i][sha3_pkg::StateW-1-:KeccakBitCapacity[L224]] = '0;
            L256: reg_state_o[i][sha3_pkg::StateW-1-:KeccakBitCapacity[L256]] = '0;
            L384: reg_state_o[i][sha3_pkg::StateW-1-:KeccakBitCapacity[L384]] = '0;
            L512: reg_state_o[i][sha3_pkg::StateW-1-:KeccakBitCapacity[L512]] = '0;
            default: reg_state_o[i] = '0;
          endcase
        end
      end
    end
  end

  assign digest_word_mask = (dynamic_keccak_strength_q == sha3_pkg::L128 && digest_word_idx_q == 3'h5)  ? { {192{1'b0}}, {64{1'b1}} } :
                            ((dynamic_keccak_strength_q == sha3_pkg::L256 && digest_word_idx_q == 3'h4) ? { {192{1'b0}}, {64{1'b1}} } : {256{1'b1}});    

  assign req_packed_digest_word = app_active_o && (app_id == 3);
  generate
  if (Share == 2) begin
    always_comb begin
      unique case (digest_word_idx_q)
        3'h0: digest_word = req_packed_digest_word ? keccak_state_i[0][255:0]     ^ keccak_state_i[1][255:0]      : 256'h0;
        3'h1: digest_word = req_packed_digest_word ? keccak_state_i[0][511:256]   ^ keccak_state_i[1][511:256]    : 256'h0;
        3'h2: digest_word = req_packed_digest_word ? keccak_state_i[0][767:512]   ^ keccak_state_i[1][767:512]    : 256'h0;
        3'h3: digest_word = req_packed_digest_word ? keccak_state_i[0][1023:768]  ^ keccak_state_i[1][1023:768]   : 256'h0;
        3'h4: digest_word = req_packed_digest_word ? keccak_state_i[0][1279:1024] ^ keccak_state_i[1][1279:1024]  : 256'h0;
        3'h5: digest_word = req_packed_digest_word ? keccak_state_i[0][1535:1280] ^ keccak_state_i[1][1535:1280]  : 256'h0;
        default: digest_word = 256'h0;
      endcase
    end
  end else begin
    always_comb begin
      unique case (digest_word_idx_q)
        3'h0: digest_word = req_packed_digest_word ? keccak_state_i[0][255:0]     : 256'h0;
        3'h1: digest_word = req_packed_digest_word ? keccak_state_i[0][511:256]   : 256'h0;
        3'h2: digest_word = req_packed_digest_word ? keccak_state_i[0][767:512]   : 256'h0;
        3'h3: digest_word = req_packed_digest_word ? keccak_state_i[0][1023:768]  : 256'h0;
        3'h4: digest_word = req_packed_digest_word ? keccak_state_i[0][1279:1024] : 256'h0;
        3'h5: digest_word = req_packed_digest_word ? keccak_state_i[0][1535:1280] : 256'h0;
        default: digest_word = 256'h0;
      endcase
    end
  end
  endgenerate
  logic squeezing_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      squeezing_q    <= 1'b0;
    end else if (prim_mubi_pkg::mubi4_test_true_strict(squeezing_i)) begin
      squeezing_q <= 1'b1;
    end else begin
      squeezing_q <= 1'b0;
    end
  end

  assign pack_digest_word = ((prim_mubi_pkg::mubi4_test_true_strict(squeezing_i) && !squeezing_q) || shift_and_pack_digest) && ~clr_appid;
  assign otbn_app_intf_done = packed_digest_word_valid && ~clr_appid && ((st == StAppWait) || (st == StAppShiftDigest) ||  (st == StAppManualRun));

  prim_packer #(
    .InW(256),
    .OutW(256),
    .HintByteData(1)
  ) u_prim_digest_packer (
    .clk_i,
    .rst_ni,
    .valid_i    (pack_digest_word),
    .data_i     (digest_word),
    .mask_i     (digest_word_mask),
    .ready_o    (digest_packer_ready),
    .valid_o    (packed_digest_word_valid),
    .data_o     (packed_digest_word),
    .mask_o     (),
    .ready_i    (req_packed_digest_word),
    .flush_i      (clr_appid),
    .flush_done_o (),
    .err_o        (digest_packer_error)
  );

  // Keccak state --> KeyMgr
  
  assign sha3_digest_done = (prim_mubi_pkg::mubi4_test_true_strict(absorbed_i) || prim_mubi_pkg::mubi4_test_true_strict(squeezing_i)) && digest_valid;
  always_comb begin
    app_digest_done = 1'b 0;
    app_digest = '{default:'0};
    if (st == StAppWait && sha3_digest_done &&
       lc_ctrl_pkg::lc_tx_test_false_strict(lc_escalate_en_i)) begin
      // SHA3 engine has calculated the hash. Return the data to KeyMgr
      app_digest_done = 1'b 1;

      // digest has always 2 entries. If !EnMasking, second is tied to 0.
      for (int i = 0 ; i < Share ; i++) begin
        app_digest[i] = keccak_state_i[i][AppDigestW-1:0];
      end
    end
  end


  // Secret Key Mux

  // Prepare merged key if EnMasking is not set.
  // Combine share keys into unpacked array for logic below to assign easily.
  // SEC_CM: KEY.SIDELOAD
  logic [MaxKeyLen-1:0] keymgr_key [Share];
  if (EnMasking == 1) begin : g_masked_key
    for (genvar i = 0; i < Share; i++) begin : gen_key_pad
      assign keymgr_key[i] =  {(MaxKeyLen-KeyMgrKeyW)'(0), keymgr_key_i.key[i]};
    end
  end else begin : g_unmasked_key
    always_comb begin
      keymgr_key[0] = '0;
      for (int i = 0; i < keymgr_pkg::Shares; i++) begin
        keymgr_key[0][KeyMgrKeyW-1:0] ^= keymgr_key_i.key[i];
      end
    end
  end

  // Sideloaded key manage: Keep use sideloaded key for KMAC AppIntf until the
  // hashing operation is finished.
  always_comb begin
    key_len_o  = reg_key_len_i;
    for (int i = 0 ; i < Share; i++) begin
      key_data_o[i] = reg_key_data_i[i];
    end

    unique case (st)
      StAppCfg, StAppMsg, StAppOutLen, StAppProcess, StAppWait: begin
        key_len_o = SideloadedKey;
        for (int i = 0 ; i < Share; i++) begin
          key_data_o[i] = keymgr_key[i];
        end
      end

      StSw: begin
        if (keymgr_key_en_i) begin
          key_len_o = SideloadedKey;
          for (int i = 0 ; i < Share; i++) begin
            key_data_o[i] = keymgr_key[i];
          end
        end
      end

      default: ;
    endcase
  end

  // Prefix Demux
  // For SW, always prefix register.
  // For App intf, check PrefixMode cfg and if 1, use Prefix cfg.
  always_comb begin
    sha3_prefix_o = '0;

    unique case (st)
      StAppCfg, StAppMsg, StAppOutLen, StAppProcess, StAppWait: begin
        // Check app intf cfg
        for (int unsigned i = 0 ; i < NumAppIntf ; i++) begin
          if (app_id == i) begin
            if (AppCfg[i].PrefixMode == 1'b 0) begin
              sha3_prefix_o = reg_prefix_i;
            end else begin
              sha3_prefix_o = AppCfg[i].Prefix;
            end
          end
        end
      end

      StSw: begin
        sha3_prefix_o = reg_prefix_i;
      end

      default: begin
        sha3_prefix_o = reg_prefix_i;
      end
    endcase
  end

  always_comb begin
    unique case (keccak_strength_o)
      sha3_pkg::L128: max_digest_words = 3'h5;
      sha3_pkg::L224: max_digest_words = 3'h1;
      sha3_pkg::L256: max_digest_words = 3'h4;
      sha3_pkg::L384: max_digest_words = 3'h2;
      sha3_pkg::L512: max_digest_words = 3'h2;
      default:        max_digest_words = 3'h0;
    endcase
  end

  // KMAC en / SHA3 mode / Strength
  //  by default, it uses reg cfg. When app intf reqs come, it uses AppCfg.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_en_o         <= 1'b 0;
      sha3_mode_o       <= sha3_pkg::Sha3;
      keccak_strength_o <= sha3_pkg::L256;
    end else if (clr_appid) begin
      // As App completed, latch reg value
      kmac_en_o         <= reg_kmac_en_i;
      sha3_mode_o       <= reg_sha3_mode_i;
      keccak_strength_o <= reg_keccak_strength_i;
    end else if (set_dynamic_sha_mode) begin
      kmac_en_o         <= 1'b 0;
      sha3_mode_o       <= dynamic_sha3_mode_q;
      keccak_strength_o <= dynamic_keccak_strength_q;
    end else if (set_appid) begin
      kmac_en_o         <= AppCfg[arb_idx].Mode == AppKMAC ? 1'b 1 : 1'b 0;
      sha3_mode_o       <= AppCfg[arb_idx].Mode == AppSHA3
                           ? sha3_pkg::Sha3 : sha3_pkg::CShake;
      keccak_strength_o <= AppCfg[arb_idx].Strength ;
    end else if (st == StIdle) begin
      kmac_en_o         <= reg_kmac_en_i;
      sha3_mode_o       <= reg_sha3_mode_i;
      keccak_strength_o <= reg_keccak_strength_i;
    end
  end

  // Status
  assign app_active_o = (st inside {StAppCfg, StAppDynamicCfg, StAppMsg,
                                    StAppOutLen, StAppProcess, StAppWait,
                                    StAppShiftDigest, StAppManualRun});

  // Error Reporting ==========================================================
  always_comb begin
    priority casez ({fsm_err.valid, mux_err.valid, digest_packer_error})
      3'b ?1: error_o = mux_err;
      3'b 10: error_o = fsm_err;
      3'b100: error_o = '{valid: 1'b0, code: ErrAppIntfPacker, info: '0};
      default: error_o = '{valid: 1'b0, code: ErrNone, info: '0};
    endcase
  end

  ////////////////
  // Assertions //
  ////////////////

  // KeyMgr sideload key and the digest should be in the Key Length value
  `ASSERT_INIT(SideloadKeySameToDigest_A, KeyMgrKeyW <= AppDigestW)
  `ASSERT_INIT(AppIntfInRange_A, AppDigestW inside {128, 192, 256, 384, 512})

  // Issue(#13655): Having a coverage that sideload keylen and CSR keylen are
  // different.
  `COVER(AppIntfUseDifferentSizeKey_C,
    (st == StAppCfg && kmac_en_o) |-> reg_key_len_i != SideloadedKey)

endmodule
