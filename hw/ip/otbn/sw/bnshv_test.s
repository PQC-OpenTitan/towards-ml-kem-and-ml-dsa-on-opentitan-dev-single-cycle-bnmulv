/* Copyright lowRISC contributors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192) */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */


/* 256-bit vector shift example. */

.section .text

/******************************/
/*    Tests for bn.shv.8S     */
/******************************/

li x2, 1
li x3, 5
li x4, 3

/* Load operands into WDRs */
bn.lid x2, 0(x0)
bn.lid x3, 32(x0)

/* Perform vector shift, limbs are 32-bit. */
bn.shv.8S w3, w1 << 4
bn.shv.8S w5, w1 >> 7

/* store results to dmem */
bn.sid x4, 512(x0)
bn.sid x3, 544(x0)

/* Perform vector shift, limbs are 16-bit. */
bn.shv.16H w3, w1 << 3
bn.shv.16H w5, w1 >> 10

/* store results to dmem */
bn.sid x4, 576(x0)
bn.sid x3, 608(x0)
ecall

.section .data

operand1:
  .quad 0x1101001010010000
  .quad 0x0001010101101010
  .quad 0x1011010011010100
  .quad 0x0001000100010001

operand2:
  .quad 0x68430849932820FD
  .quad 0xDAA04543B00FE032
  .quad 0x123F454A01F001F4
  .quad 0xBB45222FC34C0014
