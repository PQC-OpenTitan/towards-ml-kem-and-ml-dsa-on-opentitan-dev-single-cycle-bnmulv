/* Copyright lowRISC contributors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192) */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */


/* 256-bit vector addition and subtraction example. */

.section .text

/******************************/
/*    Tests for bn.addv.8S    */
/******************************/

/* Load mod WSR with base li pseudo-instruction*/
li x23, 0x7fe001
csrrw x0, 0x7d0, x23

/* Load operands into WDRs */
li x2, 0
li x3, 1
li x4, 32

bn.lid x2, 0(x0)
bn.lid x3, 0(x4)

/* Perform vector addition and subtraction, limbs are 32-bit. */

bn.addv.8S w3, w0, w1
bn.subv.8S w2, w0, w1

/* store result from [w2, w3] to dmem */
li x4, 2
bn.sid x4++, 512(x0)
bn.sid x4++, 544(x0)


/* Load operands into WDRs */
li x2, 0
li x3, 1
li x4, 32

bn.lid x2, 64(x0)
bn.lid x3, 0(x4)

/* Perform vector addition and subtraction, limbs are 32-bit. */

bn.addv.8S w3, w0, w1
bn.subv.8S w2, w0, w1

/* store result from [w2, w3] to dmem */
li x4, 2
bn.sid x4++, 576(x0)
bn.sid x4++, 608(x0)

/******************************/
/*    Tests for bn.addv.16H   */
/******************************/

/* Load mod WSR with base li pseudo-instruction*/
li x23, 0x00000D01
csrrw x0, 0x7d0, x23

/* Load operands into WDRs */
li x2, 0
li x3, 1
li x4, 32

bn.lid x2, 96(x0)
bn.lid x3, 128(x0)

/* Perform vector addition and subtraction, limbs are 32-bit. */

bn.addv.16H w3, w0, w1
bn.subv.16H w2, w0, w1

/* store result from [w2, w3] to dmem */
li x4, 2
bn.sid x4++, 640(x0)
bn.sid x4++, 672(x0)

/* Load operands into WDRs */
li x2, 0
li x3, 1
li x4, 32

bn.lid x2, 160(x0)
bn.lid x3, 128(x0)

/* Perform vector addition and subtraction, limbs are 32-bit. */

bn.addv.16H w3, w0, w1
bn.subv.16H w2, w0, w1

/* store result from [w2, w3] to dmem */
li x4, 2
bn.sid x4++, 704(x0)
bn.sid x4++, 736(x0)


ecall

.section .data

/* 256-bit integer
   0000000800000007 0000000600000005
   0000000400000003 0000000200000001 
   (.quad below is in reverse order) */

operand1:
  .quad 0x0000000200000001
  .quad 0x0000000400000003
  .quad 0x0000000600000005
  .quad 0x0000000800000007

/* 256-bit integer
   0000000800000007 0000000600000005
   0000000400000003 0000000200000001 
   (.quad below is in reverse order) */

operand2:
  .quad 0x0000000200000001
  .quad 0x0000000400000003
  .quad 0x0000000600000005
  .quad 0x0000000800000007

/* Expected result is
   w3 =
   0000000400000002 0000000800000006
   0000001200000010 0000001600000014
   w2 =
   0000000000000000 0000000000000000
   0000000000000000 0000000000000000 */



/* 256-bit integer
   ffffffffffffffff ffffffffffffffff
   ffffffffffffffff ffffffffffffffff 
   (.quad below is in reverse order) */

operand3:
  .quad 0xffffffffffffffff
  .quad 0xffffffffffffffff
  .quad 0xffffffffffffffff
  .quad 0xffffffffffffffff


/* Expected result is
   w3 =
   0000000700000006 0000000500000004
   0000000300000002 0000000100000000 
   w2 =
   fffffff7fffffff8 fffffff9fffffffa
   fffffffbfffffffc fffffffdfffffffe */

/* 256-bit integer
   0010000f000e000d 000c000b000a0009
   0008000700060005 0004000300020001 
   (.quad below is in reverse order) */

operand4:
  .quad 0x0004000300020001
  .quad 0x0008000700060005
  .quad 0x000c000b000a0009
  .quad 0x0010000f000e000d

/* Expected result is
   w3 =
   0020001e 001c001a 00180016 00140012
   0010000e000c000a 0008000600040002 
   w2 =
   0000000000000000 0000000000000000
   0000000000000000 0000000000000000 */

operand5:
  .quad 0x0004000300020001
  .quad 0x0008000700060005
  .quad 0x000c000b000a0009
  .quad 0x0010000f000e000d
/* Expected result is
   w3 =
   000f000e 000d000c 000b000a 00090008
   00070006 00050004 00030002 00010000    
   w2 =
   ffeffff0 fff1fff2 fff3fff4 fff5fff6
   fff7fff8 fff9fffa fffbfffc fffdfffe */

operand6:
  .quad 0xffffffffffffffff
  .quad 0xffffffffffffffff
  .quad 0xffffffffffffffff
  .quad 0xffffffffffffffff