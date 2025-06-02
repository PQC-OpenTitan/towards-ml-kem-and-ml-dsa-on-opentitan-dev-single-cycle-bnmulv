// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192)
// Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors

`include "prim_assert.sv"

/**
 * OTBN alu block for the bignum instruction subset
 *
 * This ALU supports all of the 'plain' arithmetic and logic bignum instructions, BN.MULQACC is
 * implemented in a separate block.
 *
 * One barrel shifter and two adders (X and Y) are implemented along with the logic operators
 * (AND,OR,XOR,NOT).
 *
 * The adders have 256-bit operands with a carry_in and optional invert on the second operand. This
 * can be used to implement subtraction (a - b == a + ~b + 1). BN.SUBB/BN.ADDC are implemented by
 * feeding in the carry flag as carry in rather than a fixed 0 or 1.
 *
 * The shifter takes a 512-bit input (to implement BN.RSHI, concatenate and right shift) and shifts
 * right by up to 256-bits. The lower (256-bit) half of the input and output can be reversed to
 * allow left shift implementation.  There is no concatenate and left shift instruction so reversing
 * isn't required over the full width.
 *
 * The dataflow between the adders and shifter is in the diagram below. This arrangement allows the
 * implementation of the pseudo-mod (BN.ADDM/BN.SUBM) instructions in a single cycle whilst
 * minimising the critical path. The pseudo-mod instructions do not have a shifted input so X can
 * compute the initial add/sub and Y computes the pseudo-mod result. For all other add/sub
 * operations Y computes the operation with one of the inputs supplied by the shifter and the other
 * from operand_a.
 *
 * Both adder X and the shifter get supplied with operand_a and operand_b from the operation_i
 * input. In addition the shifter gets a shift amount (shift_amt) and can use 0 instead of
 * operand_a. The shifter concatenates operand_a (or 0) and operand_b together before shifting with
 * operand_a in the upper (256-bit) half {operand_a/0, operand_b}. This allows the shifter to pass
 * through operand_b simply by not performing a shift.
 *
 * Blanking is employed on the ALU data paths. This holds unused data paths to 0 to reduce side
 * channel leakage. The lower-case 'b' on the digram below indicates points in the data path that
 * get blanked. Note that Adder X is never used in isolation, it is always combined with Adder Y so
 * there is no need for blanking between Adder X and Adder Y.
 *
 *      A       B       A   B
 *      |       |       |   |
 *      b       b       b   b   shift_amt
 *      |       |       |   |   |
 *    +-----------+   +-----------+
 *    |  Adder X  |   |  Shifter  |
 *    +-----------+   +-----------+
 *          |               |
 *          |----+     +----|
 *          |    |     |    |
 *      X result |     | Shifter result
 *               |     |
 *             A |     |
 *             | |     |     +-----------+
 *             b |     b +---|  MOD WSR  |
 *             | |     | |   +-----------+
 *           \-----/ \-----/
 *            \---/   \---/
 *              |       |
 *              |       |
 *            +-----------+
 *            |  Adder Y  |
 *            +-----------+
 *                  |
 *              Y result
 */


module otbn_alu_bignum
  import otbn_pkg::*;
(
  input logic clk_i,
  input logic rst_ni,

  input  alu_bignum_operation_t operation_i,
  input  logic                  operation_valid_i,
  input  logic                  operation_commit_i, // used for SVAs only
  output logic [WLEN-1:0]       operation_result_o,
  output logic                  selection_flag_o,

  output logic [63:0]           mod_o,

  input  alu_predec_bignum_t  alu_predec_bignum_i,
  input  ispr_predec_bignum_t ispr_predec_bignum_i,

  input  ispr_e                       ispr_addr_i,
  input  logic [31:0]                 ispr_base_wdata_i,
  input  logic [BaseWordsPerWLEN-1:0] ispr_base_wr_en_i,
  input  logic [ExtWLEN-1:0]          ispr_bignum_wdata_intg_i,
  input  logic                        ispr_bignum_wr_en_i,
  input  logic [NFlagGroups-1:0]      ispr_flags_wr_i,
  input  logic                        ispr_wr_commit_i,
  input  logic                        ispr_init_i,
  output logic [ExtWLEN-1:0]          ispr_rdata_intg_o,
  input  logic                        ispr_rd_en_i,

  input  logic [ExtWLEN-1:0]          ispr_acc_intg_i,
  output logic [ExtWLEN-1:0]          ispr_acc_wr_data_intg_o,
  output logic                        ispr_acc_wr_en_o,

  output logic                        reg_intg_violation_err_o,

  input logic                         sec_wipe_mod_urnd_i,
  input logic                         sec_wipe_kmac_regs_urnd_i,

  input  flags_t                      mac_operation_flags_i,
  input  flags_t                      mac_operation_flags_en_i,

  input  logic [WLEN-1:0]             rnd_data_i,
  input  logic [WLEN-1:0]             urnd_data_i,

  input  logic [1:0][SideloadKeyWidth-1:0] sideload_key_shares_i,

  output logic alu_predec_error_o,
  output logic ispr_predec_error_o,

  output logic kmac_msg_write_ready_o,
  output logic kmac_digest_valid_o,

  output kmac_pkg::app_req_t          kmac_app_req_o,
  input  kmac_pkg::app_rsp_t          kmac_app_rsp_i
);

  logic [WLEN+1:0] adder_y_res;
  logic [WLEN-1:0] logical_res;

  ///////////
  // ISPRs //
  ///////////

  flags_t                              flags_d [NFlagGroups];
  flags_t                              flags_q [NFlagGroups];
  logic   [NFlagGroups*FlagsWidth-1:0] flags_flattened;
  flags_t                              selected_flags;
  flags_t                              adder_update_flags;
  logic                                adder_update_flags_en_raw;
  flags_t                              logic_update_flags [NFlagGroups];
  logic                                logic_update_flags_en_raw;
  flags_t                              mac_update_flags [NFlagGroups];
  logic [NFlagGroups-1:0]              mac_update_z_flag_en_blanked;
  flags_t                              ispr_update_flags [NFlagGroups];

  logic [NIspr-1:0] expected_ispr_rd_en_onehot;
  logic [NIspr-1:0] expected_ispr_wr_en_onehot;
  logic             ispr_wr_en;

  logic [NFlagGroups-1:0] expected_flag_group_sel;
  flags_t                 expected_flag_sel;
  logic [NFlagGroups-1:0] expected_flags_keep;
  logic [NFlagGroups-1:0] expected_flags_adder_update;
  logic [NFlagGroups-1:0] expected_flags_logic_update;
  logic [NFlagGroups-1:0] expected_flags_mac_update;
  logic [NFlagGroups-1:0] expected_flags_ispr_wr;

  /////////////////////
  // Flags Selection //
  /////////////////////

  always_comb begin
    expected_flag_group_sel = '0;
    expected_flag_group_sel[operation_i.flag_group] = 1'b1;
  end
  assign expected_flag_sel.C = operation_i.sel_flag == FlagC;
  assign expected_flag_sel.M = operation_i.sel_flag == FlagM;
  assign expected_flag_sel.L = operation_i.sel_flag == FlagL;
  assign expected_flag_sel.Z = operation_i.sel_flag == FlagZ;

  // SEC_CM: DATA_REG_SW.SCA
  prim_onehot_mux #(
    .Width(FlagsWidth),
    .Inputs(NFlagGroups)
  ) u_flags_q_mux (
    .clk_i,
    .rst_ni,
    .in_i  (flags_q),
    .sel_i (alu_predec_bignum_i.flag_group_sel),
    .out_o (selected_flags)
  );

  `ASSERT(BlankingSelectedFlags_A, expected_flag_group_sel == '0 |-> selected_flags == '0, clk_i,
    !rst_ni || alu_predec_error_o  || !operation_commit_i)


  logic                  flag_mux_in [FlagsWidth];
  logic [FlagsWidth-1:0] flag_mux_sel;
  assign flag_mux_in = '{selected_flags.C,
                         selected_flags.M,
                         selected_flags.L,
                         selected_flags.Z};
  assign flag_mux_sel = {alu_predec_bignum_i.flag_sel.Z,
                         alu_predec_bignum_i.flag_sel.L,
                         alu_predec_bignum_i.flag_sel.M,
                         alu_predec_bignum_i.flag_sel.C};

  // SEC_CM: DATA_REG_SW.SCA
  prim_onehot_mux #(
    .Width(1),
    .Inputs(FlagsWidth)
  ) u_flag_mux (
    .clk_i,
    .rst_ni,
    .in_i  (flag_mux_in),
    .sel_i (flag_mux_sel),
    .out_o (selection_flag_o)
  );

  `ASSERT(BlankingSelectionFlag_A, expected_flag_sel == '0 |-> selection_flag_o == '0, clk_i,
    !rst_ni || alu_predec_error_o  || !operation_commit_i)

  //////////////////
  // Flags Update //
  //////////////////

  // Note that the flag zeroing triggred by ispr_init_i and secure wipe is achieved by not
  // selecting any inputs in the one-hot muxes below. The instruction fetch/predecoder stage
  // is driving the selector inputs accordingly.

  always_comb begin
    expected_flags_adder_update = '0;
    expected_flags_logic_update = '0;
    expected_flags_mac_update   = '0;

    expected_flags_adder_update[operation_i.flag_group] = operation_i.alu_flag_en &
                                                          adder_update_flags_en_raw;
    expected_flags_logic_update[operation_i.flag_group] = operation_i.alu_flag_en &
                                                          logic_update_flags_en_raw;
    expected_flags_mac_update[operation_i.flag_group]   = operation_i.mac_flag_en;
  end
  assign expected_flags_ispr_wr = ispr_flags_wr_i;

  assign expected_flags_keep = ~(expected_flags_adder_update |
                                 expected_flags_logic_update |
                                 expected_flags_mac_update |
                                 expected_flags_ispr_wr);

  // Adder operations update all flags.
  assign adder_update_flags.C = (operation_i.op == AluOpBignumAdd ||
                                 operation_i.op == AluOpBignumAddc) ?  adder_y_res[WLEN+1] :
                                                                      ~adder_y_res[WLEN+1];
  assign adder_update_flags.M = adder_y_res[WLEN];
  assign adder_update_flags.L = adder_y_res[1];
  assign adder_update_flags.Z = ~|adder_y_res[WLEN:1];

  for (genvar i_fg = 0; i_fg < NFlagGroups; i_fg++) begin : g_update_flag_groups

    // Logical operations only update M, L and Z; C must remain at its old value.
    assign logic_update_flags[i_fg].C = flags_q[i_fg].C;
    assign logic_update_flags[i_fg].M = logical_res[WLEN-1];
    assign logic_update_flags[i_fg].L = logical_res[0];
    assign logic_update_flags[i_fg].Z = ~|logical_res;

    ///////////////
    // MAC Flags //
    ///////////////

    // MAC operations don't update C.
    assign mac_update_flags[i_fg].C = flags_q[i_fg].C;

    // Tie off unused signals.
    logic unused_mac_operation_flags;
    assign unused_mac_operation_flags = mac_operation_flags_i.C ^ mac_operation_flags_en_i.C;

    // MAC operations update M and L depending on the operation. The individual enable signals for
    // M and L are generated from flopped instruction bits with minimal logic. They are not data
    // dependent.
    assign mac_update_flags[i_fg].M = mac_operation_flags_en_i.M ?
                                      mac_operation_flags_i.M : flags_q[i_fg].M;
    assign mac_update_flags[i_fg].L = mac_operation_flags_en_i.L ?
                                      mac_operation_flags_i.L : flags_q[i_fg].L;

    // MAC operations update Z depending on the operation and data. For BN.MULQACC.SO, already the
    // enable signal is data dependent (it depends on the lower half of the accumulator result). As
    // a result the enable signal might change back and forth during instruction execution which may
    // lead to SCA leakage. There is nothing that can really be done to avoid this other than
    // pipelining the flag computation which has a peformance impact.
    //
    // By blanking the enable signal for the other flag group, we can at least avoid leakage related
    // to the other flag group, i.e., we give the programmer a way to control where the leakage
    // happens.
    // SEC_CM: DATA_REG_SW.SCA
    prim_blanker #(.Width(1)) u_mac_z_flag_en_blanker (
      .in_i (mac_operation_flags_en_i.Z),
      .en_i (alu_predec_bignum_i.flags_mac_update[i_fg]),
      .out_o(mac_update_z_flag_en_blanked[i_fg])
    );
    assign mac_update_flags[i_fg].Z = mac_update_z_flag_en_blanked[i_fg] ?
                                      mac_operation_flags_i.Z : flags_q[i_fg].Z;

    // For ISPR writes, we get the full write data from the base ALU and will select the relevant
    // parts using the blankers and one-hot muxes below.
    assign ispr_update_flags[i_fg] = ispr_base_wdata_i[i_fg*FlagsWidth+:FlagsWidth];
  end

  localparam int NFlagsSrcs = 5;
  for (genvar i_fg = 0; i_fg < NFlagGroups; i_fg++) begin : g_flag_groups

    flags_t                flags_d_mux_in [NFlagsSrcs];
    logic [NFlagsSrcs-1:0] flags_d_mux_sel;
    assign flags_d_mux_in = '{ispr_update_flags[i_fg],
                              mac_update_flags[i_fg],
                              logic_update_flags[i_fg],
                              adder_update_flags,
                              flags_q[i_fg]};
    assign flags_d_mux_sel = {alu_predec_bignum_i.flags_keep[i_fg],
                              alu_predec_bignum_i.flags_adder_update[i_fg],
                              alu_predec_bignum_i.flags_logic_update[i_fg],
                              alu_predec_bignum_i.flags_mac_update[i_fg],
                              alu_predec_bignum_i.flags_ispr_wr[i_fg]};

    // SEC_CM: DATA_REG_SW.SCA
    prim_onehot_mux #(
      .Width(FlagsWidth),
      .Inputs(NFlagsSrcs)
    ) u_flags_d_mux (
      .clk_i,
      .rst_ni,
      .in_i  (flags_d_mux_in),
      .sel_i (flags_d_mux_sel),
      .out_o (flags_d[i_fg])
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        flags_q[i_fg] <= '{Z : 1'b0, L : 1'b0, M : 1'b0, C : 1'b0};
      end else begin
        flags_q[i_fg] <= flags_d[i_fg];
      end
    end

    assign flags_flattened[i_fg*FlagsWidth+:FlagsWidth] = flags_q[i_fg];
  end

  //////////
  // MOD //
  /////////

  logic [ExtWLEN-1:0]          mod_intg_q;
  logic [ExtWLEN-1:0]          mod_intg_d;
  logic [BaseWordsPerWLEN-1:0] mod_ispr_wr_en;
  logic [BaseWordsPerWLEN-1:0] mod_wr_en;

  logic [ExtWLEN-1:0] ispr_mod_kmac_bignum_wdata_intg_blanked;

  logic ispr_mod_kmac_en;
  assign ispr_mod_kmac_en = ispr_predec_bignum_i.ispr_wr_en[IsprMod] |
                            ispr_predec_bignum_i.ispr_wr_en[IsprKmacMsg] |
                            ispr_predec_bignum_i.ispr_wr_en[IsprKmacCfg];

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(ExtWLEN)) u_ispr_mod_bignum_wdata_blanker (
    .in_i (ispr_bignum_wdata_intg_i),
    .en_i (ispr_mod_kmac_en),
    .out_o(ispr_mod_kmac_bignum_wdata_intg_blanked)
  );
  // If the blanker is enabled, the output will not carry the correct ECC bits.  This is not
  // a problem because a blanked value should never be written to the register.  If the blanked
  // value is written to the register nonetheless, an integrity error arises.

  logic [WLEN-1:0]                mod_no_intg_d;
  logic [WLEN-1:0]                mod_no_intg_q;
  logic [ExtWLEN-1:0]             mod_intg_calc;
  logic [2*BaseWordsPerWLEN-1:0]  mod_intg_err;
  for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_mod_words
    prim_secded_inv_39_32_enc i_mod_secded_enc (
      .data_i (mod_no_intg_d[i_word*32+:32]),
      .data_o (mod_intg_calc[i_word*39+:39])
    );
    prim_secded_inv_39_32_dec i_mod_secded_dec (
      .data_i     (mod_intg_q[i_word*39+:39]),
      .data_o     (/* unused because we abort on any integrity error */),
      .syndrome_o (/* unused */),
      .err_o      (mod_intg_err[i_word*2+:2])
    );
    assign mod_no_intg_q[i_word*32+:32] = mod_intg_q[i_word*39+:32];

    always_ff @(posedge clk_i) begin
      if (mod_wr_en[i_word]) begin
        mod_intg_q[i_word*39+:39] <= mod_intg_d[i_word*39+:39];
      end
    end

    always_comb begin
      mod_no_intg_d[i_word*32+:32] = '0;
      unique case (1'b1)
        // Non-encoded inputs have to be encoded before writing to the register.
        sec_wipe_mod_urnd_i: begin
          // In a secure wipe, `urnd_data_i` is written to the register before the zero word.  The
          // ECC bits should not matter between the two writes, but nonetheless we encode
          // `urnd_data_i` so there is no spurious integrity error.
          mod_no_intg_d[i_word*32+:32] = urnd_data_i[i_word*32+:32];
          mod_intg_d[i_word*39+:39]  = mod_intg_calc[i_word*39+:39];
        end
        // Pre-encoded inputs can directly be written to the register.
        default: begin
          mod_intg_d[i_word*39+:39] = ispr_mod_kmac_bignum_wdata_intg_blanked[i_word*39+:39];
        end
      endcase

      unique case (1'b1)
        ispr_init_i: mod_intg_d[i_word*39+:39] = EccZeroWord;
        ispr_base_wr_en_i[i_word]: begin
          mod_no_intg_d[i_word*32+:32] = ispr_base_wdata_i;
          mod_intg_d[i_word*39+:39] = mod_intg_calc[i_word*39+:39];
        end
        default: ;
      endcase
    end

    `ASSERT(ModWrSelOneHot, $onehot0({ispr_init_i, ispr_base_wr_en_i[i_word]}))

    assign mod_ispr_wr_en[i_word] = (ispr_addr_i == IsprMod)                          &
                                    (ispr_base_wr_en_i[i_word] | ispr_bignum_wr_en_i) &
                                    ispr_wr_commit_i;

    assign mod_wr_en[i_word] = ispr_init_i            |
                               mod_ispr_wr_en[i_word] |
                               sec_wipe_mod_urnd_i;
  end


  // Output mod register for use in MULV
  assign mod_o = mod_no_intg_q[63:0];

  //////////
  // KMAC //
  //////////

  // CFG
  logic [BaseIntgWidth-1:0] kmac_cfg_intg_q;
  logic [31:0]              kmac_cfg_no_intg_d;
  logic [BaseIntgWidth-1:0] kmac_cfg_intg_d;
  logic [BaseIntgWidth-1:0] kmac_cfg_intg_calc;
  logic                     kmac_cfg_ispr_wr_en;
  logic                     kmac_cfg_wr_en;
  logic [1:0]               kmac_cfg_intg_err;

  prim_secded_inv_39_32_enc u_kmac_cfg_secded_enc (
    .data_i (kmac_cfg_no_intg_d),
    .data_o (kmac_cfg_intg_calc)
  );
  prim_secded_inv_39_32_dec u_kmac_cfg_secded_dec (
    .data_i     (kmac_cfg_intg_q),
    .data_o     (/* unused because we abort on any integrity error */),
    .syndrome_o (/* unused */),
    .err_o      (kmac_cfg_intg_err)
  );

  always_ff @(posedge clk_i) begin
    if (kmac_cfg_wr_en) begin
      kmac_cfg_intg_q <= kmac_cfg_intg_d;
    end
  end

  always_comb begin
    unique case (1'b1)
      ispr_init_i: begin
        kmac_cfg_no_intg_d  = 32'b0;
        kmac_cfg_intg_d     = kmac_cfg_intg_calc;
      end
      ispr_base_wr_en_i[0]: begin
        kmac_cfg_no_intg_d  = ispr_base_wdata_i;
        kmac_cfg_intg_d     = kmac_cfg_intg_calc;
      end
      default: begin
        kmac_cfg_no_intg_d  = 32'b0;
        kmac_cfg_intg_d     = ispr_mod_kmac_bignum_wdata_intg_blanked[38:0];
      end
    endcase
  end

  `ASSERT(KmacCfgWrSelOneHot, $onehot0({ispr_init_i, ispr_base_wr_en_i[0]}))

  assign kmac_cfg_ispr_wr_en = (ispr_addr_i == IsprKmacCfg)               &
                               (ispr_base_wr_en_i[0] | ispr_bignum_wr_en_i)  &
                               ispr_wr_commit_i;

  assign kmac_cfg_wr_en = (ispr_init_i | kmac_cfg_ispr_wr_en) & !kmac_app_rsp_i.error;

  // MSG
  logic [ExtWLEN-1:0]           kmac_msg_intg_q;
  logic [ExtWLEN-1:0]           kmac_msg_intg_d;
  logic [BaseWordsPerWLEN-1:0]  kmac_msg_ispr_wr_en;
  logic [BaseWordsPerWLEN-1:0]  kmac_msg_wr_en;

  logic [WLEN-1:0]                kmac_msg_no_intg_d;
  logic [WLEN-1:0]                kmac_msg_no_intg_q;
  logic [ExtWLEN-1:0]             kmac_msg_intg_calc;
  logic [2*BaseWordsPerWLEN-1:0]  kmac_msg_intg_err;

  for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_kmac_msg_words
    prim_secded_inv_39_32_enc i_kmac_msg_secded_enc (
      .data_i (kmac_msg_no_intg_d[i_word*32+:32]),
      .data_o (kmac_msg_intg_calc[i_word*39+:39])
    );
    prim_secded_inv_39_32_dec i_kmac_msg_secded_dec (
      .data_i     (kmac_msg_intg_q[i_word*39+:39]),
      .data_o     (/* unused because we abort on any integrity error */),
      .syndrome_o (/* unused */),
      .err_o      (kmac_msg_intg_err[i_word*2+:2])
    );

    always_ff @(posedge clk_i) begin
      if (kmac_msg_wr_en[i_word]) begin
        kmac_msg_intg_q[i_word*39+:39] <= kmac_msg_intg_d[i_word*39+:39];
      end
    end
    assign kmac_msg_no_intg_q[i_word*32+:32] = kmac_msg_intg_q[i_word*39+:32];

    always_comb begin
      kmac_msg_no_intg_d[i_word*32+:32] = '0;
      kmac_msg_intg_d[i_word*39+:39] = '0;
      unique case (1'b1)
        // Non-encoded inputs have to be encoded before writing to the register.
        sec_wipe_kmac_regs_urnd_i: begin
          kmac_msg_no_intg_d[i_word*32+:32] = urnd_data_i[i_word*32+:32];
          kmac_msg_intg_d[i_word*39+:39] = kmac_msg_intg_calc[i_word*39+:39];
        end
        // Pre-encoded inputs can directly be written to the register.
        default: begin
          kmac_msg_intg_d[i_word*39+:39] = ispr_mod_kmac_bignum_wdata_intg_blanked[i_word*39+:39];
        end
      endcase
    end

    `ASSERT(KmacMsgWrSelOneHot, $onehot0({ispr_init_i, ispr_base_wr_en_i[i_word]}))

    assign kmac_msg_ispr_wr_en[i_word] = (ispr_addr_i == IsprKmacMsg)                      &
                                         (ispr_base_wr_en_i[i_word] | ispr_bignum_wr_en_i) &
                                         ispr_wr_commit_i;

    assign kmac_msg_wr_en[i_word] = ispr_init_i                                             |
                                    (kmac_msg_ispr_wr_en[i_word] & kmac_msg_write_ready_o) |
                                    sec_wipe_kmac_regs_urnd_i;
  end

  // STATUS
  logic kmac_new_cfg_q;
  logic [BaseIntgWidth-1:0] kmac_status_intg_q;
  logic [BaseIntgWidth-1:0] kmac_status_intg_d;
  logic [31:0]              kmac_status_no_intg_d;
  logic [1:0]               kmac_status_intg_err;

  assign kmac_status_no_intg_d = kmac_new_cfg_q ? 32'b0 : {29'b0, kmac_app_rsp_i.error, kmac_app_rsp_i.ready, kmac_app_rsp_i.done};

  prim_secded_inv_39_32_enc u_kmac_status_secded_enc (
    .data_i (kmac_status_no_intg_d),
    .data_o (kmac_status_intg_d)
  );
  prim_secded_inv_39_32_dec u_kmac_status_secded_dec (
    .data_i     (kmac_status_intg_q),
    .data_o     (/* unused because we abort on any integrity error */),
    .syndrome_o (/* unused */),
    .err_o      (kmac_status_intg_err)
  );

  always_ff @(posedge clk_i) begin
    kmac_status_intg_q <= kmac_status_intg_d;
  end

  // DIGEST
  localparam int DigestRegLen = 256;
  localparam int ExtDigestLen = DigestRegLen * 39 / 32;
  localparam int BaseWordsPerDigestLen = DigestRegLen / 32;

  logic [383:0]                         unused_digest_share1;
  logic [DigestRegLen-1:0]              kmac_digest_no_intg_d;
  logic [ExtDigestLen-1:0]              kmac_digest_intg_q;
  logic [ExtDigestLen-1:0]              kmac_digest_intg_d;
  logic [BaseWordsPerDigestLen-1:0]     kmac_digest_wr_en;
  logic [2*BaseWordsPerDigestLen-1:0]   kmac_digest_intg_err;
  logic                                 kmac_digest_rd_next;
  logic                                 kmac_digest_valid_q;
  logic                                 kmac_digest_rd;

  assign kmac_digest_valid_o = kmac_digest_valid_q & ~kmac_digest_rd;
  assign kmac_digest_rd_next = kmac_digest_rd && ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_digest_rd <= 1'b0;
    end else if (kmac_digest_rd_next || kmac_new_cfg_q) begin
      kmac_digest_rd <= 1'b0;
    end else if (ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest] && kmac_digest_valid_q) begin
      kmac_digest_rd <= 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_digest_valid_q <= 1'b0;
    end else if (kmac_digest_rd_next || kmac_new_cfg_q) begin
      kmac_digest_valid_q <= 1'b0;
    end else if (kmac_app_rsp_i.done) begin
      kmac_digest_valid_q <= 1'b1;
    end
  end

  for (genvar i_word = 0; i_word < BaseWordsPerDigestLen; i_word++) begin : g_kmac_digest_words
    prim_secded_inv_39_32_enc i_kmac_digest_secded_enc (
      .data_i (kmac_digest_no_intg_d[i_word*32+:32]),
      .data_o (kmac_digest_intg_d[i_word*39+:39])
    );
    prim_secded_inv_39_32_dec i_kmac_digest_secded_dec (
      .data_i     (kmac_digest_intg_q[i_word*39+:39]),
      .data_o     (/* unused because we abort on any integrity error */),
      .syndrome_o (/* unused */),
      .err_o      (kmac_digest_intg_err[i_word*2+:2])
    );

    always_ff @(posedge clk_i) begin
      if (kmac_digest_wr_en[i_word]) begin
        kmac_digest_intg_q[i_word*39+:39] <= kmac_digest_intg_d[i_word*39+:39];
      end
    end

    assign kmac_digest_no_intg_d[i_word*32+:32] = sec_wipe_kmac_regs_urnd_i ?
                                                     urnd_data_i[(i_word % BaseWordsPerWLEN)*32+:32] :
                                                     kmac_app_rsp_i.digest_share0[i_word*32+:32];

    assign kmac_digest_wr_en[i_word] = kmac_app_rsp_i.done | sec_wipe_kmac_regs_urnd_i;
  end

  // For now, the digest shares are xor'ed directly (blanked and only for OTBN app intf)
  // in the KMAC app intf and share0 carries the unmasked digest.
  assign unused_digest_share1 = kmac_app_rsp_i.digest_share1;

  // MSG INTERFACE
  sha3_pkg::sha3_mode_e       kmac_cfg_sha3_mode;
  sha3_pkg::keccak_strength_e kmac_cfg_keccak_strength;
  logic [10:0]                kmac_cfg_unused_msg_len;
  logic [14:0]                kmac_cfg_msg_len;
  logic [11:0]                kmac_cfg_msg_len_words;
  logic [2:0]                 kmac_cfg_msg_len_bytes;
  logic [11:0]                kmac_msg_ctr;

  logic                           kmac_msg_clr;
  logic                           kmac_msg_fifo_wvalid;
  logic                           kmac_msg_fifo_wready;
  logic [WLEN-1:0]                kmac_msg_fifo_wdata;
  logic                           kmac_msg_fifo_rvalid;
  logic                           kmac_msg_fifo_rready;
  logic [kmac_pkg::MsgWidth-1:0]  kmac_msg_fifo_rdata;
  logic                           kmac_last_msg_all_bytes_valid;
  logic [kmac_pkg::MsgStrbW-1:0]  kmac_last_msg_strb;

  logic kmac_msg_active_q;
  logic kmac_cfg_active_q;
  logic kmac_msg_valid_q;
  logic kmac_write_cfg_to_app;
  logic kmac_msg_ctr_err;
  logic kmac_msg_last;
  logic kmac_idle_q;
  logic kmac_cfg_done;

  assign kmac_cfg_sha3_mode       = sha3_pkg::sha3_mode_e'(kmac_cfg_intg_q[1:0]);
  assign kmac_cfg_keccak_strength = sha3_pkg::keccak_strength_e'(kmac_cfg_intg_q[4:2]);
  assign kmac_cfg_done            = kmac_cfg_intg_q[31];
  assign kmac_cfg_unused_msg_len  = kmac_cfg_intg_q[30:20];
  assign kmac_cfg_msg_len         = kmac_cfg_intg_q[19:5];
  assign kmac_cfg_msg_len_words   = kmac_cfg_msg_len[14:3];
  assign kmac_cfg_msg_len_bytes   = kmac_cfg_msg_len[2:0];
  assign kmac_msg_clr             = kmac_app_rsp_i.error | sec_wipe_kmac_regs_urnd_i | kmac_msg_ctr_err;

  assign kmac_last_msg_all_bytes_valid = &(~kmac_cfg_msg_len_bytes);
  for (genvar i_bit=1; i_bit<kmac_pkg::MsgStrbW+1; i_bit++) begin
    assign kmac_last_msg_strb[i_bit-1] = kmac_last_msg_all_bytes_valid ? 1'b1 :
                                                          (i_bit <= kmac_cfg_msg_len_bytes) ? 1'b1 : 1'b0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_new_cfg_q  <= 1'b0;
    end else if (kmac_cfg_wr_en & ~sec_wipe_kmac_regs_urnd_i & ~ispr_init_i) begin
      kmac_new_cfg_q <= 1'b1;
    end else begin
      kmac_new_cfg_q <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_msg_active_q <= 1'b0;
      kmac_cfg_active_q <= 1'b0;
    end else if (kmac_new_cfg_q) begin
      kmac_cfg_active_q <= 1'b1;
      kmac_msg_active_q <= 1'b0;
    end else if (kmac_msg_clr || kmac_idle_q) begin
      kmac_cfg_active_q <= 1'b0;
      kmac_msg_active_q <= 1'b0;
    end else if (kmac_msg_fifo_wready) begin
      kmac_msg_active_q <= kmac_cfg_active_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_msg_valid_q <= 1'b0;
    end else if (|(kmac_msg_wr_en) & ~sec_wipe_kmac_regs_urnd_i & ~ispr_init_i) begin
      kmac_msg_valid_q <= 1'b1;
    end else if (kmac_msg_fifo_wready) begin
      kmac_msg_valid_q <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      kmac_idle_q <= 1'b1;
    end else if (kmac_cfg_done) begin
      kmac_idle_q <= 1'b1;
    end else begin
      kmac_idle_q <= 1'b0;
    end
  end

  assign kmac_write_cfg_to_app = kmac_cfg_active_q && ~kmac_msg_active_q && ~kmac_idle_q;

  prim_packer_fifo #(
    .InW    ( WLEN                ),
    .OutW   ( kmac_pkg::MsgWidth  )
  ) u_kmac_msg_fifo (
    .clk_i,
    .rst_ni,

    .clr_i    ( kmac_msg_clr || kmac_new_cfg_q ),

    .wvalid_i ( kmac_msg_fifo_wvalid  ),
    .wready_o ( kmac_msg_fifo_wready  ),
    .wdata_i  ( kmac_msg_fifo_wdata   ),

    .rvalid_o ( kmac_msg_fifo_rvalid  ),
    .rready_i ( kmac_msg_fifo_rready  ),
    .rdata_o  ( kmac_msg_fifo_rdata   ),

    .depth_o  ( /* unused */          )
  );

  prim_count #(
    .Width (12),
    .EnableAlertTriggerSVA('0)
  ) u_kmac_msg_ctr (
    .clk_i,
    .rst_ni,

    .clr_i              ( kmac_msg_clr || kmac_new_cfg_q              ),
    .set_i              ( 1'b0                                        ),
    .set_cnt_i          ( {(12){1'b0}}                     ),
    .incr_en_i          ( kmac_msg_fifo_rvalid & kmac_app_rsp_i.ready ),
    .decr_en_i          ( 1'b0                                        ),
    .step_i             ( {{(11){1'b0}}, {1'b1}}         ),
    .commit_i           ( 1'b1              ),
    .cnt_o              ( kmac_msg_ctr      ),
    .cnt_after_commit_o ( /* unused */      ),
    .err_o              ( kmac_msg_ctr_err  )
  );


  // fifo write iface
  assign kmac_msg_fifo_wdata  = kmac_msg_no_intg_q;
  assign kmac_msg_fifo_wvalid = kmac_msg_valid_q & kmac_msg_fifo_wready;
  assign kmac_msg_write_ready_o = kmac_msg_fifo_wready;

  // fifo read iface
  assign kmac_msg_last        = (kmac_cfg_msg_len_bytes == 3'h0) ? (kmac_msg_ctr >= kmac_cfg_msg_len_words - 1) : (kmac_msg_ctr >= kmac_cfg_msg_len_words);
  assign kmac_msg_fifo_rready = kmac_app_rsp_i.ready;
  assign kmac_app_req_o.valid = kmac_write_cfg_to_app ? 1'b1 : kmac_msg_fifo_rvalid & ~kmac_new_cfg_q;
  assign kmac_app_req_o.data  = kmac_write_cfg_to_app ?
                                  {59'b0, kmac_cfg_keccak_strength, kmac_cfg_sha3_mode} :
                                  kmac_msg_fifo_rdata;
  assign kmac_app_req_o.strb  = kmac_app_req_o.last ? kmac_last_msg_strb : {(kmac_pkg::MsgStrbW){1'b1}};
  assign kmac_app_req_o.last  = kmac_msg_fifo_rvalid & kmac_msg_last;
  assign kmac_app_req_o.next  = kmac_digest_rd & ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest];
  assign kmac_app_req_o.hold  = kmac_cfg_active_q & ~kmac_new_cfg_q;

  /////////
  // ACC //
  /////////

  assign ispr_acc_wr_en_o   =
    ((ispr_addr_i == IsprAcc) & ispr_bignum_wr_en_i & ispr_wr_commit_i) | ispr_init_i;


  logic [ExtWLEN-1:0] ispr_acc_bignum_wdata_intg_blanked;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(ExtWLEN)) u_ispr_acc_bignum_wdata_intg_blanker (
    .in_i (ispr_bignum_wdata_intg_i),
    .en_i (ispr_predec_bignum_i.ispr_wr_en[IsprAcc]),
    .out_o(ispr_acc_bignum_wdata_intg_blanked)
  );
  // If the blanker is enabled, the output will not carry the correct ECC bits.  This is not
  // a problem because a blanked value should never be used.  If the blanked value is used
  // nonetheless, an integrity error arises.

  assign ispr_acc_wr_data_intg_o = ispr_init_i ? EccWideZeroWord
                                               : ispr_acc_bignum_wdata_intg_blanked;

  // ISPR read data is muxed out in two stages:
  // 1. Select amongst the ISPRs that have no integrity bits. The output has integrity calculated
  //    for it.
  // 2. Select between the ISPRs that have integrity bits and the result of the first stage.

  // Number of ISPRs that have integrity protection
  localparam int NIntgIspr = 4;
  // IDs fpr ISPRs with integrity
  localparam int IsprModIntg                = 0;
  localparam int IsprAccIntg                = 1;
  localparam int IsprKmacMsgIntg            = 2;
  localparam int IsprKmacDigestIntg         = 3;
  // ID representing all ISPRs with no integrity
  localparam int IsprNoIntg                 = 4;

  logic [NIntgIspr:0] ispr_rdata_intg_mux_sel;
  logic [ExtWLEN-1:0] ispr_rdata_intg_mux_in    [NIntgIspr+1];
  logic [WLEN-1:0]    ispr_rdata_no_intg_mux_in [NIspr];

  // First stage
  // MOD, ACC, KMAC_MSG and KMAC_DIGEST supply their own integrity so these values are unused
  assign ispr_rdata_no_intg_mux_in[IsprMod]         = 0;
  assign ispr_rdata_no_intg_mux_in[IsprAcc]         = 0;
  assign ispr_rdata_no_intg_mux_in[IsprKmacMsg]     = 0;
  assign ispr_rdata_no_intg_mux_in[IsprKmacDigest]  = 0;

  assign ispr_rdata_no_intg_mux_in[IsprRnd]    = rnd_data_i;
  assign ispr_rdata_no_intg_mux_in[IsprUrnd]   = urnd_data_i;
  assign ispr_rdata_no_intg_mux_in[IsprFlags]  = {{(WLEN - (NFlagGroups * FlagsWidth)){1'b0}},
                                                 flags_flattened};
  // SEC_CM: KEY.SIDELOAD
  assign ispr_rdata_no_intg_mux_in[IsprKeyS0L] = sideload_key_shares_i[0][255:0];
  assign ispr_rdata_no_intg_mux_in[IsprKeyS0H] = {{(WLEN - (SideloadKeyWidth - 256)){1'b0}},
                                                  sideload_key_shares_i[0][SideloadKeyWidth-1:256]};
  assign ispr_rdata_no_intg_mux_in[IsprKeyS1L] = sideload_key_shares_i[1][255:0];
  assign ispr_rdata_no_intg_mux_in[IsprKeyS1H] = {{(WLEN - (SideloadKeyWidth - 256)){1'b0}},
                                                  sideload_key_shares_i[1][SideloadKeyWidth-1:256]};

  assign ispr_rdata_no_intg_mux_in[IsprKmacCfg] = {224'b0, kmac_cfg_intg_q[31:0]};
  assign ispr_rdata_no_intg_mux_in[IsprKmacStatus]  = {224'b0, kmac_status_intg_q[31:0]};

  logic [WLEN-1:0]    ispr_rdata_no_intg;
  logic [ExtWLEN-1:0] ispr_rdata_intg_calc;

  // SEC_CM: DATA_REG_SW.SCA
  prim_onehot_mux #(
    .Width  (WLEN),
    .Inputs (NIspr)
  ) u_ispr_rdata_no_intg_mux (
    .clk_i,
    .rst_ni,
    .in_i  (ispr_rdata_no_intg_mux_in),
    .sel_i (ispr_predec_bignum_i.ispr_rd_en),
    .out_o (ispr_rdata_no_intg)
  );

  for (genvar i_word = 0; i_word < BaseWordsPerWLEN; i_word++) begin : g_rdata_enc
    prim_secded_inv_39_32_enc i_secded_enc (
      .data_i(ispr_rdata_no_intg[i_word * 32 +: 32]),
      .data_o(ispr_rdata_intg_calc[i_word * 39 +: 39])
    );
  end

  // Second stage
  assign ispr_rdata_intg_mux_in[IsprModIntg]        = mod_intg_q;
  assign ispr_rdata_intg_mux_in[IsprAccIntg]        = ispr_acc_intg_i;
  assign ispr_rdata_intg_mux_in[IsprKmacMsgIntg]    = kmac_msg_intg_q;
  assign ispr_rdata_intg_mux_in[IsprKmacDigestIntg] = kmac_digest_intg_q;
  assign ispr_rdata_intg_mux_in[IsprNoIntg]         = ispr_rdata_intg_calc;

  assign ispr_rdata_intg_mux_sel[IsprModIntg]         = ispr_predec_bignum_i.ispr_rd_en[IsprMod];
  assign ispr_rdata_intg_mux_sel[IsprAccIntg]         = ispr_predec_bignum_i.ispr_rd_en[IsprAcc];
  assign ispr_rdata_intg_mux_sel[IsprKmacMsgIntg]     = ispr_predec_bignum_i.ispr_rd_en[IsprKmacMsg];
  assign ispr_rdata_intg_mux_sel[IsprKmacDigestIntg] = ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest];

  assign ispr_rdata_intg_mux_sel[IsprNoIntg]  =
    |{ispr_predec_bignum_i.ispr_rd_en[IsprKeyS1H:IsprKeyS0L],
      ispr_predec_bignum_i.ispr_rd_en[IsprUrnd],
      ispr_predec_bignum_i.ispr_rd_en[IsprFlags],
      ispr_predec_bignum_i.ispr_rd_en[IsprRnd],
      ispr_predec_bignum_i.ispr_rd_en[IsprKmacCfg],
      ispr_predec_bignum_i.ispr_rd_en[IsprKmacStatus]};

  // If we're reading from an ISPR we must be using the ispr_rdata_intg_mux
  `ASSERT(IsprRDataIntgMuxSelIfIsprRd_A,
    |ispr_predec_bignum_i.ispr_rd_en |-> |ispr_rdata_intg_mux_sel)

  // If we're reading from MOD or ACC we must not take the read data from the calculated integrity
  // path
  `ASSERT(IsprModMustTakeIntg_A,
    ispr_predec_bignum_i.ispr_rd_en[IsprMod] |-> !ispr_rdata_intg_mux_sel[IsprNoIntg])

  `ASSERT(IsprAccMustTakeIntg_A,
    ispr_predec_bignum_i.ispr_rd_en[IsprAcc] |-> !ispr_rdata_intg_mux_sel[IsprNoIntg])


  prim_onehot_mux #(
    .Width  (ExtWLEN),
    .Inputs (NIntgIspr+1)
  ) u_ispr_rdata_intg_mux (
    .clk_i,
    .rst_ni,
    .in_i  (ispr_rdata_intg_mux_in),
    .sel_i (ispr_rdata_intg_mux_sel),
    .out_o (ispr_rdata_intg_o)
  );

  prim_onehot_enc #(
    .OneHotWidth (NIspr)
  ) u_expected_ispr_rd_en_enc (
    .in_i(ispr_addr_i),
    .en_i (ispr_rd_en_i),
    .out_o (expected_ispr_rd_en_onehot)
  );

  assign ispr_wr_en = |{ispr_bignum_wr_en_i, ispr_base_wr_en_i};

  prim_onehot_enc #(
    .OneHotWidth (NIspr)
  ) u_expected_ispr_wr_en_enc (
    .in_i(ispr_addr_i),
    .en_i (ispr_wr_en),
    .out_o (expected_ispr_wr_en_onehot)
  );

  // SEC_CM: CTRL.REDUN
  assign ispr_predec_error_o =
    |{expected_ispr_rd_en_onehot != ispr_predec_bignum_i.ispr_rd_en,
      expected_ispr_wr_en_onehot != ispr_predec_bignum_i.ispr_wr_en};

  /////////////
  // Shifter //
  /////////////

  logic [WLEN-1:0]   shifter_res, unused_shifter_out_upper;
  logic [WLEN-1:0]   shifter_operand_a_blanked;
  logic [WLEN-1:0]   shifter_operand_b_blanked;
  logic [WLEN-1:0]   shifter_bignum_in_upper, shifter_bignum_in_lower, shifter_bignum_in_lower_reverse;
  logic [WLEN*2-1:0] shifter_bignum_in;
  logic [WLEN*2-1:0] shifter_bignum_out;
  logic [WLEN-1:0]   shifter_bignum_out_lower_reverse;
  logic [WLEN-1:0]   shifter_bignum_res;
  logic [15:0]       shifter_vec_in [15:0];
  logic [15:0]       shifter_vec_in_orig [15:0];
  logic [15:0]       shifter_vec_in_reverse [15:0];
  logic [15:0]       shifter_vec_out [15:0];
  logic [31:0]       shifter_vec_tmp [15:0];
  logic [31:0]       shifter_vec_tmp_shifted [15:0];
  logic [15:0]       shifter_vec_out_reverse [15:0];
  logic [WLEN-1:0]   shifter_vec_res;
  logic              shifter_selvector_i;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_shifter_operand_a_blanker (
    .in_i (operation_i.operand_a),
    .en_i (alu_predec_bignum_i.shifter_a_en),
    .out_o(shifter_operand_a_blanked)
  );

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_shifter_operand_b_blanker (
    .in_i (operation_i.operand_b),
    .en_i (alu_predec_bignum_i.shifter_b_en),
    .out_o(shifter_operand_b_blanked)
  );

  // BIGNUM SHIFTER
  // Operand A is only used for BN.RSHI, otherwise the upper input is 0. For all instructions other
  // than BN.RHSI alu_predec_bignum_i.shifter_a_en will be 0, resulting in 0 for the upper input.
  assign shifter_bignum_in_upper = shifter_operand_a_blanked;
  assign shifter_bignum_in_lower = shifter_operand_b_blanked;

  for (genvar i = 0; i < WLEN; i++) begin : g_shifter_bignum_in_lower_reverse
    assign shifter_bignum_in_lower_reverse[i] = shifter_bignum_in_lower[WLEN-i-1];
  end

  assign shifter_bignum_in = {shifter_bignum_in_upper,
      alu_predec_bignum_i.shift_right ? shifter_bignum_in_lower : shifter_bignum_in_lower_reverse};

  assign shifter_bignum_out = shifter_bignum_in >> alu_predec_bignum_i.shift_amt;

  for (genvar i = 0; i < WLEN; i++) begin : g_shifter_bignum_out_lower_reverse
    assign shifter_bignum_out_lower_reverse[i] = shifter_bignum_out[WLEN-i-1];
  end

  assign shifter_bignum_res = alu_predec_bignum_i.shift_right ? shifter_bignum_out[WLEN-1:0] : shifter_bignum_out_lower_reverse;

  // VECTOR SHIFTER
  // TODO: arithmetic shift
  assign shifter_selvector_i = operation_i.vector_type[0];
  // split into 16-bit chunks for vectorized shift
  for (genvar i=0; i<16; ++i) begin : g_shifter_vec
    assign shifter_vec_in_orig[i] = shifter_operand_b_blanked[i*16+:16];
    for (genvar j=0; j<WLEN/16; ++j) begin : g_shifter_vec_reverse_input
      assign shifter_vec_in_reverse[i][j] = shifter_vec_in_orig[i][WLEN/16-j-1];
    end
    assign shifter_vec_in[i] = alu_predec_bignum_i.shift_right ? shifter_vec_in_orig[i] : 
                                                                 shifter_selvector_i ? shifter_vec_in_reverse[i] :
                                                                                       (i % 2 == 1) ? shifter_vec_in_reverse[i-1] :
                                                                                                      shifter_vec_in_reverse[i+1];
    // Shifter below either shifts as 16 or 32 bit vectors
    assign shifter_vec_tmp[i] = {shifter_vec_in[i+1], shifter_vec_in[i]};
    assign shifter_vec_tmp_shifted[i] = shifter_vec_tmp[i] >> alu_predec_bignum_i.shift_amt;
    assign shifter_vec_out[i] = (shifter_selvector_i | (i % 2 == 1)) ? (shifter_vec_in[i] >> alu_predec_bignum_i.shift_amt) :
                                                                       shifter_vec_tmp_shifted[i][15:0];

    for (genvar j=0; j<WLEN/16; ++j) begin : g_shifter_vec_reverse_output
      assign shifter_vec_out_reverse[i][j] = shifter_selvector_i ? shifter_vec_out[i][WLEN/16-j-1] :
                                                                   (i % 2 == 1) ? shifter_vec_out[i-1][WLEN/16-j-1] :
                                                                                  shifter_vec_out[i+1][WLEN/16-j-1];
    end
    assign shifter_vec_res[i*16+:16] = alu_predec_bignum_i.shift_right ?
                                        shifter_vec_out[i] :
                                        shifter_vec_out_reverse[i];
  end

  // SHIFTER RESULT
  assign shifter_res = (operation_i.op == otbn_pkg::AluOpBignumShv) ? shifter_vec_res : shifter_bignum_res;
  // Only the lower WLEN bits of the shift result are returned.
  assign unused_shifter_out_upper = shifter_bignum_out[WLEN*2-1:WLEN];

  ///////////////
  // Transpose //
  ///////////////

  logic [WLEN/16-1:0]  trn_op0_16h [15:0];
  logic [WLEN/8-1:0]   trn_op0_8s  [7:0];
  logic [WLEN/4-1:0]   trn_op0_4d  [3:0];
  logic [WLEN/2-1:0]   trn_op0_2q  [1:0];

  logic [WLEN/16-1:0]  trn_op1_16h [15:0];
  logic [WLEN/8-1:0]   trn_op1_8s  [7:0];
  logic [WLEN/4-1:0]   trn_op1_4d  [3:0];
  logic [WLEN/2-1:0]   trn_op1_2q  [1:0];

  logic [WLEN-1:0]     trn_res;

  for (genvar i=0; i<16; ++i) begin : g_trn_16h
    assign trn_op0_16h[i] = operation_i.operand_a[i*16+:16];
    assign trn_op1_16h[i] = operation_i.operand_b[i*16+:16];
  end

  for (genvar i=0; i<8; ++i) begin : g_trn_8s
    assign trn_op0_8s[i] = operation_i.operand_a[i*32+:32];
    assign trn_op1_8s[i] = operation_i.operand_b[i*32+:32];
  end

  for (genvar i=0; i<4; ++i) begin : g_trn_4d
    assign trn_op0_4d[i] = operation_i.operand_a[i*64+:64];
    assign trn_op1_4d[i] = operation_i.operand_b[i*64+:64];
  end

  for (genvar i=0; i<2; ++i) begin : g_trn_2q
    assign trn_op0_2q[i] = operation_i.operand_a[i*128+:128];
    assign trn_op1_2q[i] = operation_i.operand_b[i*128+:128];
  end

  always_comb begin
    case (operation_i.trn_type)
      trn1_16h: begin
        for (int i=0; i<8; ++i) begin
          trn_res[i*32+:32] = {trn_op1_16h[2*i],trn_op0_16h[2*i]};
        end
      end

      trn1_8s: begin
        for (int i=0; i<4; ++i) begin
          trn_res[i*64+:64] = {trn_op1_8s[2*i],trn_op0_8s[2*i]};
        end        
      end   

      trn1_4d: begin
        for (int i=0; i<2; ++i) begin
          trn_res[i*128+:128] = {trn_op1_4d[2*i],trn_op0_4d[2*i]};
        end           
      end  

      trn1_2q: begin
        for (int i=0; i<1; ++i) begin
          trn_res[i*256+:256] = {trn_op1_2q[2*i],trn_op0_2q[2*i]};
        end  
      end

      trn2_16h: begin
        for (int i=0; i<8; ++i) begin
          trn_res[i*32+:32] = {trn_op1_16h[2*i+1],trn_op0_16h[2*i+1]};
        end
      end

      trn2_8s: begin
        for (int i=0; i<4; ++i) begin
          trn_res[i*64+:64] = {trn_op1_8s[2*i+1],trn_op0_8s[2*i+1]};
        end        
      end  

      trn2_4d: begin
        for (int i=0; i<2; ++i) begin
          trn_res[i*128+:128] = {trn_op1_4d[2*i+1],trn_op0_4d[2*i+1]};
        end          
      end     

      trn2_2q: begin
        for (int i=0; i<1; ++i) begin
          trn_res[i*256+:256] = {trn_op1_2q[2*i+1],trn_op0_2q[2*i+1]};
        end 
      end

      default: begin
        for (int i=0; i<8; ++i) begin
          trn_res[i*32+:32] = {trn_op1_16h[2*i],trn_op0_16h[2*i]};
        end
      end
    endcase
  end


  //////////////////
  // Adders X & Y //
  //////////////////

  //logic [WLEN:0]   adder_x_op_a_blanked, adder_x_op_b, adder_x_op_b_blanked;
  logic            adder_x_carry_in;
  logic            adder_x_carry_in_blanked;
  logic            adder_x_op_b_invert;
  logic [WLEN:0]  adder_x_res;

  // logic [WLEN:0]   adder_y_op_a, adder_y_op_b;
  logic            adder_y_carry_in;
  logic            adder_y_op_b_invert;
  // logic [WLEN-1:0] adder_y_op_a_blanked;
  logic [WLEN-1:0] adder_y_op_shifter_res_blanked;

  logic [WLEN-1:0] shift_mod_mux_out;
  logic [WLEN-1:0] x_res_operand_a_mux_out;

  // Splitt 256-bit addition into 16 x 16-bit additions
  logic [15:0] adder_x_op_a [15:0];
  logic [15:0] adder_x_op_b [15:0];

  logic [16:0] adder_x_op_a_blanked [15:0];
  logic [16:0] adder_x_op_b_blanked [15:0];

  logic [15:0] adder_y_op_a_blanked [15:0];
  logic [16:0] adder_y_op_a [15:0];
  logic [16:0] adder_y_op_b [15:0];

  logic [15:0] adder_x_vcarry_in;
  logic [15:0] adder_y_vcarry_in;

  logic [15:0] adder_x_sum [15:0];
  logic [15:0] adder_y_sum [15:0];

  logic [15:0] adder_x_carry_out;
  logic [15:0] adder_y_carry_out;

  logic [15:0] adder_x_carry2mux;
  logic [15:0] adder_y_carry2mux;

  logic [15:0] adder_x_carry_in_unused;
  logic [15:0] adder_y_carry_in_unused;

  logic adder_selvector_i;
  logic adder_vector_i;
  assign adder_selvector_i = operation_i.vector_type[0];
  assign adder_vector_i = operation_i.vector_sel;

    // SEC_CM: DATA_REG_SW.SCA
    prim_blanker #(.Width(1)) u_adder_op_b_blanked (
      .in_i (adder_x_carry_in),
      .en_i (alu_predec_bignum_i.adder_x_en),
      .out_o(adder_x_carry_in_blanked)
    );

  for (genvar i=0; i<16; ++i) begin

    // Depending on mode, select carry input for the 16-bit adders
    // ToDo: cleaner and better readbable code, very ugly --> UNOPTFLAT
    // ToDo: carry in vector as input
    assign adder_x_vcarry_in[i] = adder_vector_i ? (adder_selvector_i ? adder_x_carry_in_blanked : 
                                                                        ((i%2==0) ? adder_x_carry_in_blanked : adder_x_carry_out[i-1])) :
                                                ((i==0) ?   adder_x_carry_in_blanked : 
                                                            adder_x_carry_out[i-1]);

    assign adder_x_op_a[i] = operation_i.operand_a[i*16+:16];

    // SEC_CM: DATA_REG_SW.SCA
    prim_blanker #(.Width(17)) u_adder_op_a_blanked (
      .in_i ({adder_x_op_a[i], 1'b1}),
      .en_i (alu_predec_bignum_i.adder_x_en),
      .out_o(adder_x_op_a_blanked[i])
    );

    assign adder_x_op_b[i] = adder_x_op_b_invert ? ~operation_i.operand_b[i*16+:16] :  operation_i.operand_b[i*16+:16];
                              

    // SEC_CM: DATA_REG_SW.SCA
    prim_blanker #(.Width(16)) u_adder_op_b_blanked (
      .in_i (adder_x_op_b[i]),
      .en_i (alu_predec_bignum_i.adder_x_en),
      .out_o(adder_x_op_b_blanked[i][16:1])
    );
    assign adder_x_op_b_blanked[i][0] = adder_x_vcarry_in[i];
    

    assign {adder_x_carry_out[i],adder_x_sum[i],adder_x_carry_in_unused[i]} = adder_x_op_a_blanked[i] + adder_x_op_b_blanked[i];

    // Combine all sums to 256-bit vector
    assign adder_x_res[1+i*16+:16] = adder_x_sum[i][15:0];

  end

  /* verilator lint_on UNOPTFLAT */

  // assign adder_x_res[WLEN+1] = adder_x_carry_out[15];
  assign adder_x_res[0] = 'b0;

  // // SEC_CM: DATA_REG_SW.SCA
  // prim_blanker #(.Width(WLEN+1)) u_adder_x_op_a_blanked (
  //   .in_i ({operation_i.operand_a, 1'b1}),
  //   .en_i (alu_predec_bignum_i.adder_x_en),
  //   .out_o(adder_x_op_a_blanked)
  // );

  // assign adder_x_op_b = {adder_x_op_b_invert ? ~operation_i.operand_b : operation_i.operand_b,
  //                        adder_x_carry_in};

  // // SEC_CM: DATA_REG_SW.SCA
  // prim_blanker #(.Width(WLEN+1)) u_adder_x_op_b_blanked (
  //   .in_i (adder_x_op_b),
  //   .en_i (alu_predec_bignum_i.adder_x_en),
  //   .out_o(adder_x_op_b_blanked)
  // );

  // assign adder_x_res = adder_x_op_a_blanked + adder_x_op_b_blanked;
  for (genvar i=0; i<16; ++i) begin

    assign adder_y_vcarry_in[i] = adder_vector_i ?  (adder_selvector_i ? adder_y_carry_in : 
                                                                        ((i%2==0) ? adder_y_carry_in : adder_y_carry_out[i-1])) :
                                                    ((i==0) ? adder_y_carry_in : 
                                                              adder_y_carry_out[i-1]);

    assign adder_x_op_a[i] = operation_i.operand_a[i*16+:16];

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(16)) u_adder_y_op_a_blanked (
    .in_i (operation_i.operand_a[i*16+:16]),
    .en_i (alu_predec_bignum_i.adder_y_op_a_en),
    .out_o(adder_y_op_a_blanked[i])
  );

  assign x_res_operand_a_mux_out[i*16+:16] =
      alu_predec_bignum_i.x_res_operand_a_sel ? adder_x_sum[i][15:0] : adder_y_op_a_blanked[i];


  assign adder_y_op_a[i] = {x_res_operand_a_mux_out[i*16+:16], 1'b1};
  assign adder_y_op_b[i] = {adder_y_op_b_invert ? ~shift_mod_mux_out[i*16+:16] : shift_mod_mux_out[i*16+:16],
                            adder_y_vcarry_in[i]};

    assign {adder_y_carry_out[i],adder_y_sum[i],adder_y_carry_in_unused[i]} = adder_y_op_a[i] + adder_y_op_b[i];

    // Combine all sums to 256-bit vector
    assign adder_y_res[1+i*16+:16] = adder_y_sum[i][15:0];
  end
  assign adder_y_res[WLEN+1] = adder_y_carry_out[15];
  assign adder_y_res[0] = 'b0;
  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_adder_y_op_shifter_blanked (
    .in_i (shifter_res),
    .en_i (alu_predec_bignum_i.adder_y_op_shifter_en),
    .out_o(adder_y_op_shifter_res_blanked)
  );
  for (genvar i=0; i<16; ++i) begin
    assign shift_mod_mux_out[i*16+:16] =
        alu_predec_bignum_i.shift_mod_sel ? adder_y_op_shifter_res_blanked[i*16+:16] :  (adder_vector_i ? (adder_selvector_i ? mod_no_intg_q[15:0] : 
                                                                                                                               mod_no_intg_q[(i%2)*16+:16]) : 
                                                                                        mod_no_intg_q[i*16+:16]);

    assign adder_x_carry2mux[i] = adder_selvector_i ? adder_x_carry_out[i] : ((i%2==0) ? adder_x_carry_out[i+1] : adder_x_carry_out[i]);
    assign adder_y_carry2mux[i] = adder_selvector_i ? adder_y_carry_out[i] : ((i%2==0) ? adder_y_carry_out[i+1] : adder_y_carry_out[i]);

  end

  // The LSb of the adder results are unused.
  logic unused_adder_x_res_lsb, unused_adder_y_res_lsb;
  assign unused_adder_x_res_lsb = adder_x_res[0];
  assign unused_adder_y_res_lsb = adder_y_res[0];

  //////////////////////////////
  // Shifter & Adders control //
  //////////////////////////////
  logic expected_adder_x_en;
  logic expected_x_res_operand_a_sel;
  logic expected_adder_y_op_a_en;
  logic expected_adder_y_op_shifter_en;
  logic expected_shifter_a_en;
  logic expected_shifter_b_en;
  logic expected_shift_right;
  logic expected_shift_mod_sel;
  alu_vector_type_t expected_vector_type;
  alu_trn_type_t expected_trn_type;
  logic expected_vector_sel;
  logic expected_logic_a_en;
  logic expected_logic_shifter_en;
  logic [3:0] expected_logic_res_sel;

  always_comb begin
    adder_x_carry_in          = 1'b0;
    adder_x_op_b_invert       = 1'b0;
    adder_y_carry_in          = 1'b0;
    adder_y_op_b_invert       = 1'b0;
    adder_update_flags_en_raw = 1'b0;
    logic_update_flags_en_raw = 1'b0;
    expected_vector_type = alu_8s;
    expected_trn_type = alu_trn_type_t'('0);
    expected_vector_sel = 1'b0;
    expected_adder_x_en             = 1'b0;
    expected_x_res_operand_a_sel    = 1'b0;
    expected_adder_y_op_a_en        = 1'b0;
    expected_adder_y_op_shifter_en  = 1'b0;
    expected_shifter_a_en           = 1'b0;
    expected_shifter_b_en           = 1'b0;
    expected_shift_right            = 1'b0;
    expected_shift_mod_sel          = 1'b1;
    expected_logic_a_en             = 1'b0;
    expected_logic_shifter_en       = 1'b0;
    expected_logic_res_sel          = '0;

    unique case (operation_i.op)
      AluOpBignumAdd: begin
        // Shifter computes B [>>|<<] shift_amt
        // Y computes A + shifter_res
        // X ignored
        adder_y_carry_in               = 1'b0;
        adder_y_op_b_invert            = 1'b0;
        adder_update_flags_en_raw      = 1'b1;
        expected_adder_y_op_shifter_en = 1'b1;

        expected_adder_y_op_a_en = 1'b1;
        expected_shifter_b_en    = 1'b1;
        expected_shift_right     = operation_i.shift_right;
      end
      AluOpBignumAddc: begin
        // Shifter computes B [>>|<<] shift_amt
        // Y computes A + shifter_res + flags.C
        // X ignored
        adder_y_carry_in               = selected_flags.C;
        adder_y_op_b_invert            = 1'b0;
        adder_update_flags_en_raw      = 1'b1;
        expected_adder_y_op_shifter_en = 1'b1;

        expected_adder_y_op_a_en = 1'b1;
        expected_shifter_b_en    = 1'b1;
        expected_shift_right     = operation_i.shift_right;
      end
      AluOpBignumAddm: begin
        // X computes A + B
        // Y computes adder_x_res - mod = adder_x_res + ~mod + 1
        // Shifter ignored
        // Output mux chooses result based on top bit of X result (whether mod subtraction in
        // Y should be applied or not)
        adder_x_carry_in    = 1'b0;
        adder_x_op_b_invert = 1'b0;
        adder_y_carry_in    = 1'b1;
        adder_y_op_b_invert = 1'b1;

        expected_adder_x_en          = 1'b1;
        expected_x_res_operand_a_sel = 1'b1;
        expected_shift_mod_sel       = 1'b0;
      end
      AluOpBignumAddv: begin
        // X computes A + B
        // Y computes adder_x_res - mod = adder_x_res + ~mod + 1
        // Shifter ignored
        // Output mux chooses result based on top bit of X result (whether mod subtraction in
        // Y should be applied or not)
        adder_x_carry_in    = 1'b0;
        adder_x_op_b_invert = 1'b0;
        adder_y_carry_in    = 1'b1;
        adder_y_op_b_invert = 1'b1;

        expected_adder_x_en          = 1'b1;
        expected_x_res_operand_a_sel = 1'b1;
        expected_shift_mod_sel       = 1'b0;
        expected_vector_type         = operation_i.vector_type;
        expected_vector_sel          = operation_i.vector_sel;
      end
      AluOpBignumAddvm: begin
        // X computes A + B
        // Y computes adder_x_res - mod = adder_x_res + ~mod + 1
        // Shifter ignored
        // Output mux chooses result based on top bit of X result (whether mod subtraction in
        // Y should be applied or not)
        adder_x_carry_in    = 1'b0;
        adder_x_op_b_invert = 1'b0;
        adder_y_carry_in    = 1'b1;
        adder_y_op_b_invert = 1'b1;

        expected_adder_x_en          = 1'b1;
        expected_x_res_operand_a_sel = 1'b1;
        expected_shift_mod_sel       = 1'b0;
        expected_vector_type         = operation_i.vector_type;
        expected_vector_sel          = operation_i.vector_sel;
      end
      AluOpBignumSub: begin
        // Shifter computes B [>>|<<] shift_amt
        // Y computes A - shifter_res = A + ~shifter_res + 1
        // X ignored
        adder_y_carry_in               = 1'b1;
        adder_y_op_b_invert            = 1'b1;
        adder_update_flags_en_raw      = 1'b1;
        expected_adder_y_op_shifter_en = 1'b1;

        expected_adder_y_op_a_en = 1'b1;
        expected_shifter_b_en    = 1'b1;
        expected_shift_right     = operation_i.shift_right;
      end
      AluOpBignumSubb: begin
        // Shifter computes B [>>|<<] shift_amt
        // Y computes A - shifter_res + ~flags.C = A + ~shifter_res + flags.C
        // X ignored
        adder_y_carry_in               = ~selected_flags.C;
        adder_y_op_b_invert            = 1'b1;
        adder_update_flags_en_raw      = 1'b1;
        expected_adder_y_op_shifter_en = 1'b1;

        expected_adder_y_op_a_en = 1'b1;
        expected_shifter_b_en    = 1'b1;
        expected_shift_right     = operation_i.shift_right;
      end
      AluOpBignumSubm: begin
        // X computes A - B = A + ~B + 1
        // Y computes adder_x_res + mod
        // Shifter ignored
        // Output mux chooses result based on top bit of X result (whether subtraction in Y should
        // be applied or not)
        adder_x_carry_in    = 1'b1;
        adder_x_op_b_invert = 1'b1;
        adder_y_carry_in    = 1'b0;
        adder_y_op_b_invert = 1'b0;

        expected_adder_x_en          = 1'b1;
        expected_x_res_operand_a_sel = 1'b1;
        expected_shift_mod_sel       = 1'b0;
      end
      AluOpBignumSubv: begin
        // X computes A - B = A + ~B + 1
        // Y computes adder_x_res + mod
        // Shifter ignored
        // Output mux chooses result based on top bit of X result (whether subtraction in Y should
        // be applied or not)
        adder_x_carry_in    = 1'b1;
        adder_x_op_b_invert = 1'b1;
        adder_y_carry_in    = 1'b0;
        adder_y_op_b_invert = 1'b0;

        expected_adder_x_en          = 1'b1;
        expected_x_res_operand_a_sel = 1'b1;
        expected_shift_mod_sel       = 1'b0;
        expected_vector_type         = operation_i.vector_type;
        expected_vector_sel          = operation_i.vector_sel;
      end
      AluOpBignumSubvm: begin
        // X computes A - B = A + ~B + 1
        // Y computes adder_x_res + mod
        // Shifter ignored
        // Output mux chooses result based on top bit of X result (whether subtraction in Y should
        // be applied or not)
        adder_x_carry_in    = 1'b1;
        adder_x_op_b_invert = 1'b1;
        adder_y_carry_in    = 1'b0;
        adder_y_op_b_invert = 1'b0;

        expected_adder_x_en          = 1'b1;
        expected_x_res_operand_a_sel = 1'b1;
        expected_shift_mod_sel       = 1'b0;
        expected_vector_type         = operation_i.vector_type;
        expected_vector_sel          = operation_i.vector_sel;
      end
      AluOpBignumRshi: begin
        // Shifter computes {A, B} >> shift_amt
        // X, Y ignored
        // Feed blanked shifter output (adder_y_op_shifter_res_blanked) to Y to avoid undesired
        // leakage in the zero flag computation.

        expected_shifter_a_en = 1'b1;
        expected_shifter_b_en = 1'b1;
        expected_shift_right  = 1'b1;
      end
      AluOpBignumXor,
      AluOpBignumOr,
      AluOpBignumAnd,
      AluOpBignumNot: begin
        // Shift computes one operand for the logical operation
        // X & Y ignored
        // Feed blanked shifter output (adder_y_op_shifter_res_blanked) to Y to avoid undesired
        // leakage in the zero flag computation.
        logic_update_flags_en_raw             = 1'b1;

        expected_shifter_b_en                 = 1'b1;
        expected_shift_right                  = operation_i.shift_right;
        expected_logic_a_en                   = operation_i.op != AluOpBignumNot;
        expected_logic_shifter_en             = 1'b1;
        expected_logic_res_sel[AluOpLogicXor] = operation_i.op == AluOpBignumXor;
        expected_logic_res_sel[AluOpLogicOr]  = operation_i.op == AluOpBignumOr;
        expected_logic_res_sel[AluOpLogicAnd] = operation_i.op == AluOpBignumAnd;
        expected_logic_res_sel[AluOpLogicNot] = operation_i.op == AluOpBignumNot;
      end
      AluOpBignumShv: begin
        expected_vector_type = operation_i.vector_type;
        expected_vector_sel = operation_i.vector_sel;
        expected_shifter_b_en           = 1'b1;
        expected_shift_right            = operation_i.shift_right;
        expected_logic_shifter_en       = 1'b1;
        expected_logic_res_sel          = '0;
      end
      AluOpBignumTrn: begin
        expected_trn_type = operation_i.trn_type;
      end
      // No operation, do nothing.
      AluOpBignumNone: ;
      default: ;
    endcase
  end

  logic [$clog2(WLEN)-1:0] expected_shift_amt;
  assign expected_shift_amt = operation_i.shift_amt;

  // SEC_CM: CTRL.REDUN
  assign alu_predec_error_o =
    |{expected_adder_x_en != alu_predec_bignum_i.adder_x_en,
      expected_x_res_operand_a_sel != alu_predec_bignum_i.x_res_operand_a_sel,
      expected_adder_y_op_a_en != alu_predec_bignum_i.adder_y_op_a_en,
      expected_adder_y_op_shifter_en != alu_predec_bignum_i.adder_y_op_shifter_en,
      expected_shifter_a_en != alu_predec_bignum_i.shifter_a_en,
      expected_shifter_b_en != alu_predec_bignum_i.shifter_b_en,
      expected_shift_right != alu_predec_bignum_i.shift_right,
      expected_vector_type != alu_predec_bignum_i.vector_type,
      expected_trn_type != alu_predec_bignum_i.trn_type,
      expected_vector_sel != alu_predec_bignum_i.vector_sel,
      expected_shift_amt != alu_predec_bignum_i.shift_amt,
      expected_shift_mod_sel != alu_predec_bignum_i.shift_mod_sel,
      expected_logic_a_en != alu_predec_bignum_i.logic_a_en,
      expected_logic_shifter_en != alu_predec_bignum_i.logic_shifter_en,
      expected_logic_res_sel != alu_predec_bignum_i.logic_res_sel,
      expected_flag_group_sel != alu_predec_bignum_i.flag_group_sel,
      expected_flag_sel != alu_predec_bignum_i.flag_sel,
      expected_flags_keep != alu_predec_bignum_i.flags_keep,
      expected_flags_adder_update != alu_predec_bignum_i.flags_adder_update,
      expected_flags_logic_update != alu_predec_bignum_i.flags_logic_update,
      expected_flags_mac_update != alu_predec_bignum_i.flags_mac_update,
      expected_flags_ispr_wr != alu_predec_bignum_i.flags_ispr_wr};

  ////////////////////////
  // Logical operations //
  ////////////////////////

  logic [WLEN-1:0] logical_res_mux_in [4];
  logic [WLEN-1:0] logical_op_a_blanked;
  logic [WLEN-1:0] logical_op_shifter_res_blanked;

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_logical_op_a_blanker (
    .in_i (operation_i.operand_a),
    .en_i (alu_predec_bignum_i.logic_a_en),
    .out_o(logical_op_a_blanked)
  );

  // SEC_CM: DATA_REG_SW.SCA
  prim_blanker #(.Width(WLEN)) u_logical_op_shifter_res_blanker (
    .in_i (shifter_res),
    .en_i (alu_predec_bignum_i.logic_shifter_en),
    .out_o(logical_op_shifter_res_blanked)
  );

  assign logical_res_mux_in[AluOpLogicXor] = logical_op_a_blanked ^ logical_op_shifter_res_blanked;
  assign logical_res_mux_in[AluOpLogicOr]  = logical_op_a_blanked | logical_op_shifter_res_blanked;
  assign logical_res_mux_in[AluOpLogicAnd] = logical_op_a_blanked & logical_op_shifter_res_blanked;
  assign logical_res_mux_in[AluOpLogicNot] = ~logical_op_shifter_res_blanked;

  // SEC_CM: DATA_REG_SW.SCA
  prim_onehot_mux #(
    .Width (WLEN),
    .Inputs(4)
  ) u_logical_res_mux (
    .clk_i,
    .rst_ni,
    .in_i  (logical_res_mux_in),
    .sel_i (alu_predec_bignum_i.logic_res_sel),
    .out_o (logical_res)
  );

  ////////////////////////
  // Output multiplexer //
  ////////////////////////

  logic adder_y_res_used;
  always_comb begin
    operation_result_o = adder_y_res[WLEN:1];
    adder_y_res_used = 1'b1;

    unique case(operation_i.op)
      AluOpBignumAdd,
      AluOpBignumAddc,
      AluOpBignumSub,
      AluOpBignumSubb: begin
        operation_result_o = adder_y_res[WLEN:1];
        adder_y_res_used = 1'b1;
      end
      // ToDo: Change
      // For pseudo-mod operations the result depends upon initial a + b / a - b result that is
      // computed in X. Operation to add/subtract mod (X + mod / X - mod) is computed in Y.
      // Subtraction is computed using in the X & Y adders as a - b == a + ~b + 1. Note that for
      // a - b the top bit of the result will be set if a - b >= 0 and otherwise clear.

      // BN.ADDM - X = a + b, Y = X - mod, subtract mod if a + b >= mod
      // * If X generates carry a + b > mod (as mod is 256-bit) - Select Y result
      // * If Y generates carry X - mod == (a + b) - mod >= 0 hence a + b >= mod, note this is only
      //   valid if X does not generate carry - Select Y result
      // * If neither happen a + b < mod - Select X result
      AluOpBignumAddm: begin
        // `adder_y_res` is always used: either as condition in the following `if` statement or, if
        // the `if` statement short-circuits, in the body of the `if` statement.
        adder_y_res_used = 1'b1;
        if (adder_x_carry_out[15] || adder_y_res[WLEN+1]) begin
          operation_result_o = adder_y_res[WLEN:1];
        end else begin
          operation_result_o = adder_x_res[WLEN:1];
        end
      end

      AluOpBignumAddv: begin
        operation_result_o = adder_x_res[WLEN:1];
      end

      AluOpBignumAddvm: begin
        // `adder_y_res` is always used: either as condition in the following `if` statement or, if
        // the `if` statement short-circuits, in the body of the `if` statement.
        //ToDo Differentiate between addv addvm
        adder_y_res_used = 1'b1;
        for (int i=0; i<16; ++i) begin
          if (adder_x_carry2mux[i] || adder_y_carry2mux[i]) begin
            operation_result_o[16*i+:16] = adder_y_sum[i];
          end else begin
            operation_result_o[16*i+:16] = adder_x_sum[i];
          end
        end

      end

      // BN.SUBM - X = a - b, Y = X + mod, add mod if a - b < 0
      // * If X generates carry a - b >= 0 - Select X result
      // * Otherwise select Y result
      AluOpBignumSubm: begin
        if (adder_x_carry_out[15]) begin
          operation_result_o = adder_x_res[WLEN:1];
          adder_y_res_used = 1'b0;
        end else begin
          operation_result_o = adder_y_res[WLEN:1];
          adder_y_res_used = 1'b1;
        end
      end

      AluOpBignumSubv: begin
        operation_result_o = adder_x_res[WLEN:1];
      end

      AluOpBignumSubvm: begin
        adder_y_res_used = 1'b1;
        for (int i=0; i<16; ++i) begin
          if (adder_x_carry2mux[i]) begin
            operation_result_o[16*i+:16] = adder_x_sum[i];
          end else begin
            operation_result_o[16*i+:16] = adder_y_sum[i];
          end          
        end

      end

      AluOpBignumRshi,
      AluOpBignumShv: begin
        operation_result_o = shifter_res[WLEN-1:0];
        adder_y_res_used = 1'b0;
      end

      AluOpBignumTrn: begin
        operation_result_o = trn_res;
        adder_y_res_used = 1'b0;
      end

      AluOpBignumXor,
      AluOpBignumOr,
      AluOpBignumAnd,
      AluOpBignumNot: begin
        operation_result_o = logical_res;
        adder_y_res_used = 1'b0;
      end

      default: ;
    endcase
  end

  // Tie off unused signals.
  logic unused_operation_commit;
  assign unused_operation_commit = operation_commit_i;

  // Determine if `mod_intg_q` is used.  The control signals are only valid if `operation_i.op` is
  // not none. If `shift_mod_sel` is low, `mod_intg_q` flows into `adder_y_op_b` and from there
  // into `adder_y_res`.  In this case, `mod_intg_q` is used iff  `adder_y_res` flows into
  // `operation_result_o`.
  logic mod_used, kmac_used;
  assign mod_used = operation_valid_i & (operation_i.op != AluOpBignumNone)
                    & !alu_predec_bignum_i.shift_mod_sel & adder_y_res_used;
  assign kmac_used = operation_valid_i & (operation_i.op != AluOpBignumNone) & (    |(ispr_predec_bignum_i.ispr_rd_en[IsprKmacMsg])     |
                                                                                    |(ispr_predec_bignum_i.ispr_rd_en[IsprKmacDigest])  |
                                                                                    |(ispr_predec_bignum_i.ispr_rd_en[IsprKmacCfg])     |
                                                                                    |(ispr_predec_bignum_i.ispr_rd_en[IsprKmacStatus])  );

  `ASSERT_KNOWN(ModUsed_A, mod_used)
  `ASSERT_KNOWN(KmacUsed_A, kmac_used)

  // Raise a register integrity violation error iff `mod_intg_q` is used and (at least partially)
  // invalid.
  assign reg_intg_violation_err_o = (mod_used & |(mod_intg_err)) | (kmac_used & ( |(kmac_msg_intg_err)    |
                                                                                  |(kmac_cfg_intg_err)    |
                                                                                  |(kmac_status_intg_err) |
                                                                                  |(kmac_digest_intg_err) ));
  `ASSERT_KNOWN(RegIntgErrKnown_A, reg_intg_violation_err_o)

  // Blanking Assertions
  // All blanking assertions are reset with predec_error or overall error in the whole system
  // -indicated by operation_commit_i port- as OTBN does not guarantee blanking in the case
  // of an error.

  // adder_x_res related blanking ToDo
  // `ASSERT(BlankingBignumAluXOp_A,
  //         !expected_adder_x_en |-> {adder_x_op_a_blanked, adder_x_op_b_blanked,adder_x_res} == '0,
  //         clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  // adder_y_res related blanking ToDo
  // `ASSERT(BlankingBignumAluYOpA_A,
  //         !expected_adder_y_op_a_en |-> adder_y_op_a_blanked == '0,
  //         clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)
  `ASSERT(BlankingBignumAluYOpShft_A,
          !expected_adder_y_op_shifter_en |-> adder_y_op_shifter_res_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  // Adder Y must be blanked when its result is not used, with one exception: For `BN.SUBM` with
  // `a >= b` (thus the result of Adder X has the carry bit set), the result of Adder Y is not used
  // but it cannot be blanked solely based on the carry bit. ToDo
  // `ASSERT(BlankingBignumAluYResUsed_A,
  //         !adder_y_res_used && !(operation_i.op == AluOpBignumSubm && adder_x_res[WLEN+1])
  //         |-> {x_res_operand_a_mux_out, adder_y_op_b} == '0,
  //         clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  // shifter_res related blanking
  `ASSERT(BlankingBignumAluShftA_A,
          !expected_shifter_a_en |-> shifter_operand_a_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  `ASSERT(BlankingBignumAluShftB_A,
          !expected_shifter_b_en |-> shifter_operand_b_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  `ASSERT(BlankingBignumAluShftRes_A,
          !(expected_shifter_a_en || expected_shifter_b_en) |-> shifter_res == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  // logical_res related blanking
  `ASSERT(BlankingBignumAluLogicOpA_A,
          !expected_logic_a_en |-> logical_op_a_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o  || !operation_commit_i)

  `ASSERT(BlankingBignumAluLogicShft_A,
          !expected_logic_shifter_en |-> logical_op_shifter_res_blanked == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)

  `ASSERT(BlankingBignumAluLogicRes_A,
          !(expected_logic_a_en || expected_logic_shifter_en) |-> logical_res == '0,
          clk_i, !rst_ni || alu_predec_error_o || !operation_commit_i)


  // MOD ISPR Blanking
  `ASSERT(BlankingIsprMod_A,
          !((|mod_wr_en) | kmac_cfg_wr_en | (|kmac_digest_wr_en) | (|kmac_msg_wr_en) | ispr_mod_kmac_en) |-> ispr_mod_kmac_bignum_wdata_intg_blanked == '0,
          clk_i, !rst_ni || ispr_predec_error_o || alu_predec_error_o || !operation_commit_i)

  // ACC ISPR Blanking
  `ASSERT(BlankingIsprACC_A,
          !(|ispr_acc_wr_en_o) |-> ispr_acc_bignum_wdata_intg_blanked == '0,
          clk_i, !rst_ni || ispr_predec_error_o || alu_predec_error_o || !operation_commit_i)


endmodule
