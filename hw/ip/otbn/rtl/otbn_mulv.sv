// Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module otbn_mulv
  import otbn_pkg::*;
(
  input mulv_bignum_operation_t operation_i,
  input logic                   mulv_en_i,
  output logic [WLEN-1:0]       multiplier_result_o
);

    /* verilator lint_off UNUSED */
    /* verilator lint_off UNOPTFLAT */

    // Operands and results for first multiplier
    // Computes p = op0_i * op1_i;
    logic [WLEN-1:0] op0, op1;
    assign op0 = operation_i.operand_a;

    // Select op1 depening on lane and lane_idx
    logic [WLEN-1:0] multiplier_op_lane;
    logic [15:0] lane16 [15:0];
    logic [31:0] lane32 [7:0];
    logic [WLEN-1:0] multiplier_op_lane16;
    logic [WLEN-1:0] multiplier_op_lane32;

    generate;
        for (genvar i=0; i<16; ++i) begin : g_lane16
            assign lane16[i] = operation_i.operand_b[i*16+:16];
        end : g_lane16

        for (genvar i=0; i<8; ++i) begin : g_lane32
            assign lane32[i] = operation_i.operand_b[i*32+:32];
        end : g_lane32
    endgenerate

    always_comb begin
      for (int i=0; i<16; ++i) begin
        multiplier_op_lane16[i*16+:16] = lane16[operation_i.lane_idx];
      end
      for (int i=0; i<8; ++i) begin
        multiplier_op_lane32[i*32+:32] = lane32[operation_i.lane_idx[2:0]];
      end      
    end

    assign multiplier_op_lane = operation_i.vector_type[0] ? multiplier_op_lane16 : multiplier_op_lane32;

    assign op1 = operation_i.vector_type[1] ? multiplier_op_lane : operation_i.operand_b;

    logic [2*WLEN-1:0] p;

    for (genvar i=0; i<4; ++i) begin
      otbn_mul u_mul0 (
          .multiplier_op_a_i(op0[i*64+:64]),
          .multiplier_op_b_i(op1[i*64+:64]),
          .multiplier_vector_i(1'b1), // 0: 64-bit, 1: vectorized
          .multiplier_selvector_i(operation_i.vector_type[0]), //1: Kyber, 0: Dilithium
          .multiplier_res_o(p[i*128+:128]) 
      );      
    end


    // Bitselect of p
    // Computes p[LOG_R-1:0]
    logic [WLEN-1:0] p_shift16, p_shift32;
    generate;
        for (genvar i=0; i<16; ++i) begin : g_shift16_p
            assign p_shift16[i*16+:16] = p[i*32+:16];
        end : g_shift16_p

        for (genvar i=0; i<8; ++i) begin : g_shift32_p
            assign p_shift32[i*32+:32] = p[i*64+:32];
        end : g_shift32_p
    endgenerate



    // Vectorize q_dash
    logic [WLEN-1:0] q_dash_16, q_dash_32;

    for (genvar i=0; i<16; ++i) begin
      assign q_dash_16[i*16+:16] = operation_i.mod[47:32];
    end

    for (genvar i=0; i<8; ++i) begin
       assign q_dash_32[i*32+:32] = operation_i.mod[63:32];
    end    
   
    // Operands and results for second multiplier
    // Computes m = p[LOG_R-1:0] * q_dash_i;
    logic [WLEN-1:0] p_shift, q_dash;
    assign p_shift = operation_i.vector_type[0] ? p_shift16 : p_shift32;
    assign q_dash = operation_i.vector_type[0] ? q_dash_16 : q_dash_32;
    logic [2*WLEN-1:0] m;


    for (genvar i=0; i<4; ++i) begin
      otbn_mul u_mul1 (
          .multiplier_op_a_i(p_shift[i*64+:64]),
          .multiplier_op_b_i(q_dash[i*64+:64]),
          .multiplier_vector_i(1'b1), // 0: 64-bit, 1: vectorized
          .multiplier_selvector_i(operation_i.vector_type[0]), //1: Kyber, 0: Dilithium
          .multiplier_res_o(m[i*128+:128]) 
      );      
    end

    // Bitselect of m
    // Computes m[LOG_R-1:0]
    logic [WLEN-1:0] m_shift16, m_shift32;
    generate;
        for (genvar i=0; i<16; ++i) begin : g_shift16_m
            assign m_shift16[i*16+:16] = m[i*32+:16];
        end : g_shift16_m

        for (genvar i=0; i<8; ++i) begin : g_shift32_m
            assign m_shift32[i*32+:32] = m[i*64+:32];
        end : g_shift32_m
    endgenerate

    // Vectorize q
    logic [WLEN-1:0] q_16, q_32;

    for (genvar i=0; i<16; ++i) begin
      assign q_16[i*16+:16] = operation_i.mod[15:0];
    end

    for (genvar i=0; i<8; ++i) begin
       assign q_32[i*32+:32] = operation_i.mod[31:0];
    end

    // Operands and results for third multiplier
    // Computes m[LOG_R-1:0] * q_i
    logic [WLEN-1:0] m_shift, q;
    assign m_shift = operation_i.vector_type[0] ? m_shift16 : m_shift32;
    assign q = operation_i.vector_type[0] ? q_16 : q_32;
    logic [2*WLEN-1:0] mq;

    for (genvar i=0; i<4; ++i) begin
      otbn_mul u_mul2 (
          .multiplier_op_a_i(m_shift[i*64+:64]),
          .multiplier_op_b_i(q[i*64+:64]),
          .multiplier_vector_i(1'b1), // 0: 64-bit, 1: vectorized
          .multiplier_selvector_i(operation_i.vector_type[0]), //1: Kyber, 0: Dilithium
          .multiplier_res_o(mq[i*128+:128]) 
      );      
    end

    // Addition of p and mq via carry select adder
    // Computes s = p + (m[LOG_R-1:0] * q_i) = p + mq;

    // Splitt 256-bit addition into 16 x 16-bit additions
    logic [31:0] adder_op_a [15:0];
    logic [32:0] adder_op_b [15:0];

    logic [32:0] adder_op_a_blanked [15:0];
    logic [32:0] adder_op_b_blanked [15:0];

    logic [15:0] adder_carry_in;
    logic [31:0] adder_sum [15:0];
    logic [15:0] adder_carry_out;
    logic [15:0] adder_carry_in_unused;

    logic adder_carry_i;
    assign adder_carry_i = 1'b0;

    logic adder_en_i;
    assign adder_en_i = 1'b1;
    for (genvar i=0; i<16; ++i) begin

        // Depending on mode, select carry input for the 32-bit adders
        assign adder_carry_in[i] = operation_i.vector_type[0] ? adder_carry_i : ((i%2==0) ? adder_carry_i : adder_carry_out[i-1]);
    
        assign adder_op_a[i] = mq[i*32+:32];

        // SEC_CM: DATA_REG_SW.SCA
        prim_blanker #(.Width(33)) u_adder_op_a_blanked (
        .in_i ({adder_op_a[i], 1'b1}),
        .en_i (adder_en_i),
        .out_o(adder_op_a_blanked[i])
        );

        assign adder_op_b[i] = {p[i*32+:32], adder_carry_in[i]};

        // SEC_CM: DATA_REG_SW.SCA
        prim_blanker #(.Width(33)) u_adder_op_b_blanked (
        .in_i (adder_op_b[i]),
        .en_i (adder_en_i),
        .out_o(adder_op_b_blanked[i])
        );

        assign {adder_carry_out[i],adder_sum[i],adder_carry_in_unused[i]} = adder_op_a_blanked[i] + adder_op_b_blanked[i];

    end


    logic [32:0] s16 [15:0];
    logic [64:0] s32 [7:0];

    logic [16:0] t16 [15:0];
    logic [32:0] t32 [7:0];

    // Extract t from s for LOG_R=DATA_WIDTH = 16(32)
    // Computes t = s[LOG_R+DATA_WIDTH:LOG_R];

    generate;
        for (genvar i=0; i<16; ++i) begin : g_t_16
            assign s16[i] = {adder_carry_out[i],adder_sum[i]};
            assign t16[i] = s16[i][32:16];

        end : g_t_16

        for (genvar i=0; i<8; ++i) begin : g_t_32
            assign s32[i] = {adder_carry_out[2*i+1],adder_sum[2*i+1],adder_sum[2*i]};
            assign t32[i] = s32[i][64:32];
        end : g_t_32
    endgenerate

    logic [16:0] t [15:0];
    
    for (genvar i=0; i<16; ++i) begin
      assign t[i] = operation_i.vector_type[0] ? t16[i] : 
                                             ((i%2==0) ? t32[i>>1][16:0] : {1'b0,t32[i>>1][32:17]});   
    end


    // Conditional subtraction if t needs to be reduced via carry select subtractor
    // Splitt 256-bit addition into 16 x 16-bit additions
    // Computes (q_i <= t) ? t : t-q_i

    logic [16:0] subtractor_op_a [15:0];
    logic [17:0] subtractor_op_b [15:0];

    logic [17:0] subtractor_op_a_blanked [15:0];
    logic [17:0] subtractor_op_b_blanked [15:0];

    logic [15:0] subtractor_carry_in;
    logic [16:0] subtractor_sum [15:0];
    logic [15:0] subtractor_carry_out;
    logic [15:0] subtractor_carry_in_unused;

    logic subtractor_carry_i;
    assign subtractor_carry_i = 1'b1;


    logic subtractor_en_i;
    assign subtractor_en_i = 1'b1;
    
    // Select t or t-q
    logic [15:0] tq_cond_16;
    logic [15:0] tq_cond_32;

    for (genvar i=0; i<16; ++i) begin
      assign tq_cond_16[i] = ({1'b0,operation_i.mod[15:0]} <= t16[i]) ? 1'b1 : 1'b0;
    end

    for (genvar i=0; i<8; ++i) begin
      assign tq_cond_32[2*i] = ({1'b0,operation_i.mod[31:0]} <= t32[i]) ? 1'b1 : 1'b0;
      assign tq_cond_32[2*i+1] = ({1'b0,operation_i.mod[31:0]}  <= t32[i]) ? 1'b1 : 1'b0;
    end

    for (genvar i=0; i<16; ++i) begin

        // Depending on mode, select carry input for the 32-bit subtractors
        assign subtractor_carry_in[i] = operation_i.vector_type[0] ? subtractor_carry_i : ((i%2==0) ? subtractor_carry_i : subtractor_carry_out[i-1]);
        
        assign subtractor_op_a[i] = t[i];

        // SEC_CM: DATA_REG_SW.SCA
        prim_blanker #(.Width(18)) u_subtractor_op_a_blanked (
        .in_i ({subtractor_op_a[i], 1'b1}),
        .en_i (subtractor_en_i),
        .out_o(subtractor_op_a_blanked[i])
        );

        assign subtractor_op_b[i] = operation_i.vector_type[0] ? {1'b1,~q[(i%2)*16+:16], subtractor_carry_in[i]} : 
                                                      (i%2==0) ? {~q[16:0], subtractor_carry_in[i]} : 
                                                                 {2'b11,~q[31:17], subtractor_carry_in[i]};
        // SEC_CM: DATA_REG_SW.SCA
        prim_blanker #(.Width(18)) u_subtractor_op_b_blanked (
        .in_i (subtractor_op_b[i]),
        .en_i (subtractor_en_i),
        .out_o(subtractor_op_b_blanked[i])
        );

        assign {subtractor_carry_out[i],subtractor_sum[i],subtractor_carry_in_unused[i]} = subtractor_op_a_blanked[i] + subtractor_op_b_blanked[i];

    end

    // Select if 16-bit or 32-bit results
    logic [15:0] tq_cond;
    assign tq_cond = operation_i.vector_type[0] ? tq_cond_16 : tq_cond_32;


    // Select if reduced or truncated result is selected as output
    logic [WLEN-1:0] multiplier_result_red;
    logic [WLEN-1:0] multiplier_result_trunc;

    always_comb
    begin
        for (int i=0; i<16; ++i) begin
          multiplier_result_trunc[16*i+:16] = p_shift[16*i+:16];
          if (tq_cond[i]==1'b1) begin
            multiplier_result_red[16*i+:16] = operation_i.vector_type[0] ? subtractor_sum[i][15:0] : ((i%2==0) ? subtractor_sum[i][15:0] : {subtractor_sum[i][14:0],subtractor_sum[i-1][16] });
          end else begin
            multiplier_result_red[16*i+:16] = operation_i.vector_type[0] ? t[i][15:0] : ((i%2==0) ? t[i][15:0] : {t[i][14:0],t[i-1][16]});
          end          
        end
    end

  assign multiplier_result_o = operation_i.vector_type[2] ? multiplier_result_red : multiplier_result_trunc;

  // Keep unused mulv_en_i to provide consistent interface between single-cycle and multi-cycle approach
  logic unused_mulv_en;
  assign unused_mulv_en = mulv_en_i;

endmodule
