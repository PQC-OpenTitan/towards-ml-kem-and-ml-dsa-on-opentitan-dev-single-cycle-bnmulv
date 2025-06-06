/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */


/*
 * Test for kyber768_base_mlkem_dec
*/

.section .text.start

/* Entry point. */
.globl main
main:
    /* Init all-zero register. */
    bn.xor  w31, w31, w31

    /* MOD <= dmem[modulus] = KYBER_Q */
    li      x5, 2
    la      x6, modulus
    bn.lid  x5, 0(x6)
    bn.wsrw 0x0, w2

    /* Load stack pointer */
    la   x2, stack_end
    la   x10, ct
    la   x11, sk 
    la   x12, key_a  
    jal  x1, crypto_kem_dec

    ecall

.data
.balign 32
.global stack
stack:
  .zero 20000
stack_end:
key_a:
  .zero 32

.balign 32
ct:
  .word 0x29a51503
  .word 0x194a5871
  .word 0x38fb48d7
  .word 0xe8fadb41
  .word 0xa4d2d9ea
  .word 0xa8f63361
  .word 0xe5e25a7e
  .word 0x2e8c3229
  .word 0x66990fdf
  .word 0x152b65f8
  .word 0xf1f606c9
  .word 0x00a27cf0
  .word 0xdd311193
  .word 0x7cee4739
  .word 0xfe85a428
  .word 0xdac38cbb
  .word 0x398dd32a
  .word 0xaf527857
  .word 0x34fc9d30
  .word 0x05d31ae5
  .word 0xbae14697
  .word 0xf78537b5
  .word 0x2929efd3
  .word 0x9c7e64cc
  .word 0x30e64bfe
  .word 0xb81466a1
  .word 0xa0ce9e12
  .word 0x4ee3f512
  .word 0xc2434bc7
  .word 0x5bb9ec62
  .word 0xa0fa9eb5
  .word 0x54c7762e
  .word 0xfce8442e
  .word 0x1e74b7b4
  .word 0x0ca8d1cb
  .word 0x44de2a04
  .word 0x8ac498fd
  .word 0x93529465
  .word 0xec45d216
  .word 0xba519042
  .word 0x719022f7
  .word 0x8ceb15ce
  .word 0x55b1f5a9
  .word 0xf6c7d02b
  .word 0xa0ac87a6
  .word 0x81227382
  .word 0x0dff545f
  .word 0x735270b0
  .word 0xa2074fe3
  .word 0x1d2361c1
  .word 0xda50ac06
  .word 0x07e7affd
  .word 0xf70dc980
  .word 0xcaf33c94
  .word 0xea094357
  .word 0x42ffee3c
  .word 0xae889b4f
  .word 0xdf19ea21
  .word 0x53183cea
  .word 0xfdaecf67
  .word 0x7ba5a1cd
  .word 0xdb52ed15
  .word 0x43e352cb
  .word 0x5e4bccb2
  .word 0xaf129a98
  .word 0x60d28b3d
  .word 0x5e4a249f
  .word 0xc0136099
  .word 0x74b9ac89
  .word 0x791b7cb9
  .word 0xaa33d4db
  .word 0xb54dfe02
  .word 0xe591d76e
  .word 0x967ddc29
  .word 0x173c4855
  .word 0x3d7accf2
  .word 0x797225b9
  .word 0xf7fe48c1
  .word 0x0845bb75
  .word 0x139d4bfc
  .word 0xfd77423e
  .word 0x15d562c0
  .word 0x95cc108a
  .word 0x6f5710a7
  .word 0xc05fed6d
  .word 0xac3a34f8
  .word 0x077d3195
  .word 0xb451365d
  .word 0x03fb2930
  .word 0x92b2a07e
  .word 0x52e13bd8
  .word 0x79572684
  .word 0xa10df64f
  .word 0xaab3e84b
  .word 0x7d02aef7
  .word 0x806730b9
  .word 0x99d5f9ee
  .word 0xed8efd0d
  .word 0xe63aa114
  .word 0x8929ccb9
  .word 0x18e26c1e
  .word 0x3881b6fa
  .word 0x6ed4b4f0
  .word 0x881e0dab
  .word 0xfd0d349f
  .word 0x65762653
  .word 0x7300ab85
  .word 0x298b11f6
  .word 0xe55c8e9d
  .word 0x85760912
  .word 0x66e0b453
  .word 0xdb6b6fda
  .word 0x704eab46
  .word 0xa44d94d5
  .word 0x634c51f7
  .word 0x6cfc87d0
  .word 0xbb3f2fea
  .word 0xbaec2dd1
  .word 0xb6b1993b
  .word 0xbce19535
  .word 0x218194b4
  .word 0xb2216c06
  .word 0x39c4f37e
  .word 0xe5905695
  .word 0x1eadca3e
  .word 0x0ee6e791
  .word 0x642307da
  .word 0xee58bc9f
  .word 0x9884a54d
  .word 0x0d412be7
  .word 0xa7322a90
  .word 0xf74ce91d
  .word 0x4bcff1b8
  .word 0xc67e9164
  .word 0x0cb8639f
  .word 0x9d1cee4b
  .word 0x088fcbd8
  .word 0xcb3cc95b
  .word 0xa793167f
  .word 0xc55ac76d
  .word 0x0e8d0e92
  .word 0xcf692dd3
  .word 0x2db53fea
  .word 0x46fd0d8b
  .word 0xee3e199d
  .word 0x02d096db
  .word 0x296ad5b8
  .word 0xe8d83ccf
  .word 0x1731364d
  .word 0x4b482db1
  .word 0xe39bf914
  .word 0xf0ef6a65
  .word 0x8764bd33
  .word 0x88f63a2f
  .word 0x2bd62688
  .word 0x8c38bcbb
  .word 0x7cee685f
  .word 0xb240fe3f
  .word 0x6e31623c
  .word 0xe950f30f
  .word 0x97098929
  .word 0x5ed707c5
  .word 0x73509d49
  .word 0x1608224c
  .word 0x40dc0aec
  .word 0x53738637
  .word 0x660b4f7a
  .word 0xdf6e790d
  .word 0x698a490d
  .word 0x9e6ba0b1
  .word 0xc1d25cbf
  .word 0x363cacc9
  .word 0x31920159
  .word 0x7271ed98
  .word 0x8bee2418
  .word 0x1799a31e
  .word 0xc944fa09
  .word 0xed346d60
  .word 0x9c8f297a
  .word 0x155801ad
  .word 0x6f5444b9
  .word 0x0cefe10e
  .word 0xf56c59b7
  .word 0xd0aad9ec
  .word 0xf8b2744d
  .word 0xdbc7e6ae
  .word 0x537bae90
  .word 0x16bbc6b5
  .word 0x978aa191
  .word 0xaed5dea9
  .word 0x0f2de917
  .word 0x06bbbdbb
  .word 0xac203220
  .word 0xef1e5fd3
  .word 0x19ff13b4
  .word 0xa4bc47bf
  .word 0x72eac130
  .word 0x57c12f33
  .word 0x78c9c5b4
  .word 0x18905cee
  .word 0x1ccfa4f9
  .word 0x4c0563f7
  .word 0x2ff2ad3f
  .word 0x781d2d5e
  .word 0x436c2132
  .word 0x23bb2f17
  .word 0xc9066ab7
  .word 0x179d9c2b
  .word 0xfe773bad
  .word 0x821bc31b
  .word 0x67cd8e6f
  .word 0x41623860
  .word 0x6b78b702
  .word 0x4fc2fa6a
  .word 0xc65df00a
  .word 0xeaab436f
  .word 0x42981b1c
  .word 0x06573121
  .word 0x3433e970
  .word 0x2370bf2d
  .word 0xa80fa3fa
  .word 0xc4f7589f
  .word 0x1524a0b6
  .word 0x2f451163
  .word 0x0a28d2bb
  .word 0x60f2fc42
  .word 0xb9975d0a
  .word 0x92ebac9e
  .word 0x4663f849
  .word 0xef5d6ed6
  .word 0x5ef64e73
  .word 0x4f5a566a
  .word 0x8038e421
  .word 0xf38199e5
  .word 0x8459499a
  .word 0xd0e40af9
  .word 0x7b914d5a
  .word 0x9e22bf64
  .word 0x9073519a
  .word 0xb200816f
  .word 0x89996040
  .word 0x68c186a1
  .word 0x39e6b7dc
  .word 0x24864f8a
  .word 0xed949bfd
  .word 0x0c15e87d
  .word 0xb72ed972
  .word 0x9160e4d3
  .word 0xa3b6d612
  .word 0x5ac7127b
  .word 0x6b563997
  .word 0x39876a1e
  .word 0x08a01cae
  .word 0x11c5a83e
  .word 0x088c3ffc
  .word 0x81b81cc6
  .word 0x9dc6c16c
  .word 0xe7022145
  .word 0x540ff68e
  .word 0x38530fa5
  .word 0x0797aca4
  .word 0x6c8b4be7
  .word 0x55c593ab
  .word 0xdc19954d
  .word 0xd4c9c114
  .word 0x2ed3747b
  .word 0x4b488a77
  .word 0x7960bae3
  .word 0xcdfc843e
  .word 0x2aa08032
  .word 0x923f67f7
  .word 0xba4dd8a8

sk:
  .word 0x1c9dc524
  .word 0xb7e70376
  .word 0x1baac74b
  .word 0x213acbc2
  .word 0xebfa3c4b
  .word 0x5bd83bb6
  .word 0x27844065
  .word 0x39ba98c4
  .word 0x27bb7143
  .word 0xb5a3921f
  .word 0x541db806
  .word 0x0d7c5aa9
  .word 0x51a1badf
  .word 0xf3d65395
  .word 0x1b605acd
  .word 0xe9b0b67d
  .word 0x4649511a
  .word 0xad681f8f
  .word 0xf38b4726
  .word 0x090e67c6
  .word 0x9ec4c43a
  .word 0x46ba907a
  .word 0x4ce95d59
  .word 0x2941e050
  .word 0x41a811a8
  .word 0xa83495b3
  .word 0xb1e70a7f
  .word 0xe2536511
  .word 0x6b569a0c
  .word 0xc7f78f9b
  .word 0xb2b828e7
  .word 0x03348901
  .word 0xa552f2a4
  .word 0x4c873052
  .word 0x78896b25
  .word 0x49a3cd34
  .word 0xcb257b80
  .word 0x86305ad7
  .word 0x3280fb7b
  .word 0x7f010082
  .word 0x560bb71c
  .word 0x656b54cc
  .word 0xdb9cdcd3
  .word 0xf17c1045
  .word 0x9634ba0d
  .word 0xc33a0419
  .word 0x46950b5c
  .word 0x90239a30
  .word 0xd53e8139
  .word 0x3a350fc4
  .word 0x19428e5e
  .word 0x61496435
  .word 0x6ca5bd12
  .word 0x1d088cb3
  .word 0x9cae52f2
  .word 0x1a447e2c
  .word 0xa7922e06
  .word 0x247adac8
  .word 0xd852990c
  .word 0xb61b5f6b
  .word 0xa5383ba5
  .word 0xa8540aac
  .word 0x2df1434b
  .word 0x5652d0a1
  .word 0x124a6855
  .word 0xb2600b09
  .word 0x8d620c8b
  .word 0x550192b0
  .word 0x0a07d147
  .word 0x2e19d6f5
  .word 0x61369663
  .word 0x54c6035d
  .word 0x8c0090bb
  .word 0x41785ba1
  .word 0x8a17f619
  .word 0xf4bed700
  .word 0x4a274aa5
  .word 0x5ce522c9
  .word 0x84a8a361
  .word 0x6358a20a
  .word 0xbca38494
  .word 0x6c3be4e2
  .word 0x27119b96
  .word 0xa1da3156
  .word 0xa01ea629
  .word 0x089f93e2
  .word 0x10a1e177
  .word 0x244ba4c8
  .word 0x07bb4fc5
  .word 0x9fdb58a9
  .word 0xb51ecaee
  .word 0x876c082b
  .word 0xb0a943bf
  .word 0x472c5b2a
  .word 0x3a7c1162
  .word 0x4e4cae99
  .word 0x337aaa2e
  .word 0x7314a7b9
  .word 0x03c11572
  .word 0x6c4f5117
  .word 0x92ef9942
  .word 0x484cd6ac
  .word 0xe75ce858
  .word 0x8901a837
  .word 0x38d72200
  .word 0x2340351f
  .word 0xf58e0c0c
  .word 0x288a840a
  .word 0xbfa09bb0
  .word 0x9c61508b
  .word 0x60515790
  .word 0x7629761d
  .word 0xc0c94974
  .word 0x21e3bab2
  .word 0x7fa738f4
  .word 0xe4552a41
  .word 0xb3b4ca5e
  .word 0x56c65390
  .word 0x39c60118
  .word 0xbe9564be
  .word 0xef44a18f
  .word 0x66af2960
  .word 0x91ca0734
  .word 0xe56d9481
  .word 0x23c7aef3
  .word 0x3bab4363
  .word 0x098aa3c5
  .word 0x2b411bc0
  .word 0x23fb0aaf
  .word 0xf2b8e9f9
  .word 0xf21008b4
  .word 0xcdfb4fce
  .word 0x7279d8bf
  .word 0x06983e32
  .word 0xbabc6051
  .word 0xd6afb334
  .word 0x47665bc2
  .word 0x9aa9fc45
  .word 0xef5ca79e
  .word 0x84769d01
  .word 0x3323ec85
  .word 0xe4399b6d
  .word 0x588d5dd0
  .word 0x3d63307b
  .word 0xe5ad694f
  .word 0x68393a75
  .word 0x4fe43502
  .word 0xa95d9927
  .word 0xa8f39867
  .word 0x9f4a185e
  .word 0x083219ad
  .word 0x419f6229
  .word 0xb77b4140
  .word 0x1a85f5db
  .word 0x135892b7
  .word 0x88d04641
  .word 0x99742745
  .word 0x1c7a081a
  .word 0x89eaea2b
  .word 0x7b0818f2
  .word 0x25ae74a7
  .word 0x274c493b
  .word 0xe01d0b75
  .word 0x53d9444b
  .word 0xb17ae4c5
  .word 0x5e20650f
  .word 0xc3f912e2
  .word 0x29e59103
  .word 0x49955395
  .word 0x0b3a8716
  .word 0x43451641
  .word 0xb0c001e8
  .word 0xf444cb99
  .word 0x58679589
  .word 0x400bc123
  .word 0x91acbbf4
  .word 0xca58a577
  .word 0x5c76300c
  .word 0x6afdab2a
  .word 0x844ca54d
  .word 0x0239e313
  .word 0x43063fd6
  .word 0x4946f030
  .word 0xe29d4282
  .word 0x3bd04c60
  .word 0x9f4ae84d
  .word 0x70541a82
  .word 0xa9403a42
  .word 0x18c4dc64
  .word 0x773d3663
  .word 0x27312cb0
  .word 0x2e944f30
  .word 0xc6981ce7
  .word 0x5327a443
  .word 0x1000f33e
  .word 0x25b84849
  .word 0xaa537927
  .word 0x5585fdab
  .word 0x775af788
  .word 0x13a299d1
  .word 0x168134ad
  .word 0xf639e5e9
  .word 0xa56870d3
  .word 0x5410c751
  .word 0x7e2c7a8b
  .word 0xd99c5fe9
  .word 0x323348b3
  .word 0x4bc43c67
  .word 0x78a718cb
  .word 0xc75594a4
  .word 0x40b3e068
  .word 0xac0211f8
  .word 0x64b0766b
  .word 0xef517105
  .word 0x43e11a10
  .word 0x85547f78
  .word 0xf88d5553
  .word 0xe03c5a03
  .word 0xcd439c0c
  .word 0xcc4231a4
  .word 0xb03490a3
  .word 0x89607e9a
  .word 0x644c7b86
  .word 0xec690a98
  .word 0x18682eab
  .word 0xcb354c72
  .word 0x455d9d90
  .word 0x9c346abc
  .word 0x5606b371
  .word 0xc0ad6476
  .word 0x98f68ecc
  .word 0x4b4b9b04
  .word 0xf6d02d43
  .word 0x5807ac9f
  .word 0xf7c4770f
  .word 0x90bb229b
  .word 0x41b397cb
  .word 0x85160788
  .word 0x4c693134
  .word 0x72f62091
  .word 0x578dd54a
  .word 0xd9ce7f12
  .word 0x2962ff99
  .word 0xc2c3d4a5
  .word 0xc89c1240
  .word 0x36c7ac12
  .word 0xd849f998
  .word 0xf26136e7
  .word 0xbf628252
  .word 0xdf5cfacc
  .word 0x6404215a
  .word 0x95e20698
  .word 0x171216ea
  .word 0xaa653308
  .word 0xaee6ce26
  .word 0xe856132f
  .word 0xfccec5e1
  .word 0x440357c8
  .word 0x0a16f17e
  .word 0x8c0e4a1b
  .word 0x38177b01
  .word 0x886cc602
  .word 0x9ad370ab
  .word 0x56c1966c
  .word 0x24865a9d
  .word 0x08eb7e5a
  .word 0x1922687d
  .word 0x74680708
  .word 0x24bf445b
  .word 0x67b5654f
  .word 0xba8d65b2
  .word 0xa52b96e6
  .word 0x1821322b
  .word 0xadcf14e2
  .word 0x0235cfd7
  .word 0xcac92d58
  .word 0xa952a9fb
  .word 0x60d37a63
  .word 0x97251007
  .word 0x239dd978
  .word 0xa95d23f8
  .word 0x4b609107
  .word 0x764f0a4f
  .word 0x590f6840
  .word 0x3dd933b6
  .word 0x2b2884fb
  .word 0x4b674ca5
  .word 0xa4845611
  .word 0xb631c31b
  .word 0x041aa659
  .word 0x5e0c3d88
  .word 0x2777c0bb
  .word 0x3bc3a454
  .word 0x2ee5906a
  .word 0x06ce7806
  .word 0xa83b45a0
  .word 0x5ab188a1
  .word 0x6aae6b49
  .word 0x637b1724
  .word 0xb0fb126d
  .word 0x95cdf288
  .word 0x0220ac04
  .word 0x31304731
  .word 0x625c1aa3
  .word 0xfb8862e4
  .word 0x8b85db3e
  .word 0xa50ebc21
  .word 0xd12f219a
  .word 0x9ea0dbc6
  .word 0xd0120792
  .word 0x7abea268
  .word 0xa3f2f4bc
  .word 0xee433453
  .word 0x41dd8017
  .word 0x60a98196
  .word 0x5faf90cd
  .word 0x158cabca
  .word 0x5725ef52
  .word 0x2b7a152f
  .word 0x184a93bb
  .word 0x767ac5a5
  .word 0x5da4541b
  .word 0xbcc64a77
  .word 0xa1833559
  .word 0xcd4dfcbc
  .word 0xab87ca0c
  .word 0x3d46ff9c
  .word 0xbb0ee8c5
  .word 0x8cd101b5
  .word 0x24e3398b
  .word 0xa07cd0db
  .word 0xba75bf6c
  .word 0xbc7a2933
  .word 0xd5bdaac7
  .word 0x1b4008b3
  .word 0x33f587a3
  .word 0x517b92f3
  .word 0xf58013e9
  .word 0x9e119ba5
  .word 0xab354835
  .word 0x2cb62d18
  .word 0x5fd8d676
  .word 0x744132a6
  .word 0x2a01523a
  .word 0x221228ac
  .word 0xe23700bc
  .word 0x77b493c4
  .word 0x59cb997a
  .word 0x55a1ab29
  .word 0x9bbc06a0
  .word 0x5f361c46
  .word 0xac3f58a3
  .word 0x03b41454
  .word 0x073591af
  .word 0x0da1339b
  .word 0xb49c81f8
  .word 0x2567f062
  .word 0xc4b3923f
  .word 0xc1b17f5a
  .word 0x91408d47
  .word 0xba1090e3
  .word 0x19100744
  .word 0x15aa0d01
  .word 0x143df4c0
  .word 0xa38f1a64
  .word 0xa2fa4ca9
  .word 0x81ae77a8
  .word 0x22f8bb13
  .word 0x2332e11e
  .word 0xfb946437
  .word 0x59828b12
  .word 0x5a10d552
  .word 0xd67d15e4
  .word 0xd5710fd7
  .word 0x4df348bd
  .word 0x62769946
  .word 0x126cce9b
  .word 0xca881c93
  .word 0x5e968208
  .word 0x278f5327
  .word 0x6b79192b
  .word 0x07261225
  .word 0x381b135b
  .word 0x15904f56
  .word 0x9ccd8395
  .word 0x8c093c4c
  .word 0x67a2068f
  .word 0x73b862b2
  .word 0x29969e1b
  .word 0x5211c476
  .word 0xb5306ca7
  .word 0x5642d002
  .word 0x437b3535
  .word 0xce3e3acd
  .word 0x1099bcf5
  .word 0x9eca89bb
  .word 0xe875ba91
  .word 0xc2531d12
  .word 0x22529b32
  .word 0x0d5612df
  .word 0x52242724
  .word 0x6e0bf63f
  .word 0x990d31ad
  .word 0x3b484d95
  .word 0x723a3891
  .word 0x1b7f936a
  .word 0xb274b460
  .word 0x19b8a52e
  .word 0x39035854
  .word 0x479f1cd8
  .word 0x3f4ab4ba
  .word 0xa733c8e0
  .word 0xb3f5a1db
  .word 0x452a5a3a
  .word 0x5c641298
  .word 0x31c23765
  .word 0x1bd76371
  .word 0xa5a4d77b
  .word 0xa1289a45
  .word 0xaa5986c2
  .word 0x9acaa1d9
  .word 0x0663a399
  .word 0x5533452d
  .word 0xa6458410
  .word 0x778e4373
  .word 0x75734e62
  .word 0xd0841a7c
  .word 0xb20fcf31
  .word 0xaa87114b
  .word 0x8e73e6fb
  .word 0xb4f5ba9a
  .word 0x1f4b002b
  .word 0x2664d9a0
  .word 0x4232c5d3
  .word 0x1e87dd35
  .word 0x4d36897a
  .word 0x67bb5e33
  .word 0x8109ad18
  .word 0x148b2054
  .word 0xeb432b3b
  .word 0x81d85f9e
  .word 0xd425526c
  .word 0x0908b494
  .word 0x039945b2
  .word 0x1d6a48c6
  .word 0x1434acb9
  .word 0x67185e94
  .word 0x2f9c86b5
  .word 0xdc9ecf88
  .word 0x8166210a
  .word 0xd3784580
  .word 0xa3e52349
  .word 0xa9bbba53
  .word 0x7790db23
  .word 0xe784b325
  .word 0x7298664e
  .word 0xe007e092
  .word 0xf266675c
  .word 0xb739f867
  .word 0xe2557c61
  .word 0x12a20f8b
  .word 0x37d0a21d
  .word 0xf90a83d6
  .word 0xfbe169d8
  .word 0x64cbb052
  .word 0xa721e25f
  .word 0xe4462a9b
  .word 0x46d38019
  .word 0x8dc5cc71
  .word 0x4b055687
  .word 0x137bca2c
  .word 0xf3055a71
  .word 0xcc555392
  .word 0x8dab38a8
  .word 0x5f252524
  .word 0x27571361
  .word 0xbcd67a16
  .word 0xbf2e63b0
  .word 0x954b3886
  .word 0x8810d20a
  .word 0xa4b492c2
  .word 0x9ce5c0fc
  .word 0x7ff7d342
  .word 0x9fcd85ac
  .word 0xb349b05c
  .word 0xa90595a2
  .word 0xacc6c484
  .word 0x0a3dca98
  .word 0xb1d2308f
  .word 0xb91598bd
  .word 0x1b05274b
  .word 0x45c3ff40
  .word 0x9e8b665a
  .word 0x61281414
  .word 0x1b0c281b
  .word 0xf6552b8f
  .word 0x0ce104eb
  .word 0x0e34f168
  .word 0x152158f1
  .word 0xb7e20ef1
  .word 0xb0ebb785
  .word 0x610c3aec
  .word 0x81f40c67
  .word 0xcd94b507
  .word 0x0d8e236e
  .word 0x471b9668
  .word 0x87873b98
  .word 0x9d517197
  .word 0x68217c2b
  .word 0xb494d41c
  .word 0x003df020
  .word 0xeb6eb04b
  .word 0x80c0f954
  .word 0xf6aff2c2
  .word 0xd5749075
  .word 0x1cb1a3b3
  .word 0x6daff173
  .word 0xecee74c8
  .word 0x09544d25
  .word 0x0fa9eafc
  .word 0xb6906df6
  .word 0x0f540a93
  .word 0x18bed9d1
  .word 0x861daf44
  .word 0x616af91f
  .word 0x6c4a411a
  .word 0xb28fa761
  .word 0x38748ea7
  .word 0xbc5eb03a
  .word 0x815a8573
  .word 0x4272628a
  .word 0xe2a323d5
  .word 0x28b45aa3
  .word 0x64254a5b
  .word 0xaa7267f7
  .word 0xf8c9cdf8
  .word 0xb4f1657c
  .word 0x059981b5
  .word 0xa59e4ffb
  .word 0xbdfb6691
  .word 0xeec501b2
  .word 0x41f70dfc
  .word 0xb511a28c
  .word 0x11a579b0
  .word 0x2944b9b8
  .word 0x7f537b84
  .word 0x572dd8be
  .word 0xe8632d63
  .word 0x2d21d815
  .word 0x430d288a
  .word 0xa6048632
  .word 0x88c1d2c4
  .word 0x61b07a7e
  .word 0x16a020f1
  .word 0x73f4b28d
  .word 0x93b16953
  .word 0xeb0a0f78
  .word 0x65f21f38
  .word 0xe2463b3f
  .word 0x7ae7af06
  .word 0x774c817e
  .word 0x66b1a116
  .word 0xa0d27d72
  .word 0xaed8a7b9
  .word 0xda25e4ac
  .word 0x817f9763
  .word 0x9f7c4503
  .word 0x76268a43
  .word 0x9c3a0ec1
  .word 0x58850b63
  .word 0xe58e2873
  .word 0xc305ca60
  .word 0x9e32c77c
  .word 0xfa2c509e
  .word 0x42b918c9
  .word 0x5d444405
  .word 0xf593fa4c
  .word 0xc722e96e
  .word 0x7b9360d6
  .word 0x07c33759
  .word 0x8f96624d
  .word 0x11126d00
  .word 0x689602c6
  .word 0xdee55359
  .word 0x2d4c80f3
  .word 0x18365cad
  .word 0xdfc13701
  .word 0x8513f312
  .word 0xe5fd70b6
  .word 0x4764e7cf
  .word 0xb5b5c4f6
  .word 0x3c558300
  .word 0xa9eeb13c
  .word 0x934b0088
  .word 0x0afb3c10
  .word 0x682afdee
  .word 0x4afa016e
  .word 0x63a3e858
  .word 0xe3a1a89c
  .word 0xe257aef9

/* Modulus: KYBER_Q = 3329 */
.globl modulus
modulus:
  .word 0x00000d01
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl modulus_bn
modulus_bn:
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01
  .word 0x0d010d01

.globl modulus_over_2
modulus_over_2:
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681
  .word 0x06810681

.globl const_0x0fff
const_0x0fff:
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff
  .word 0x0fff0fff

.globl const_1290167
const_1290167:
  .word 0x0013afb7
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl const_8
const_8:
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  .word 0x00080008
  
/* 1/Q mod 2^32 */
.globl qinv
qinv:
  .word 0x6ba8f301
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl const_toplant
const_toplant:
  .word 0x97f44fab
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000

.globl twiddles_ntt_base
twiddles_ntt_base:
    /* Layer 1--4 */ 
  .word 0x84f5c5b6, 0x00000000
  .word 0xc666e465, 0x00000000
  .word 0xfcec8b58, 0x00000000
  .word 0xcb2b72d0, 0x00000000
  .word 0x30726d5b, 0x00000000
  .word 0x91e11612, 0x00000000
  .word 0x41360f89, 0x00000000
  .word 0x51aaf2da, 0x00000000
  .word 0x93922fd5, 0x00000000
  .word 0x0ed77946, 0x00000000
  .word 0x3d4a0dff, 0x00000000
  .word 0xd63e49fb, 0x00000000
  .word 0xfab1a391, 0x00000000
  .word 0x2bc18ea7, 0x00000000
  .word 0x864470e4, 0x00000000
  /* Padding */
  .word 0x00000000, 0x00000000
  /* Layer 5 - 1 */
  .word 0x16c32c11, 0x00000000
  /* Layer 6 - 1 */
  .word 0x16395e0d, 0x00000000
  .word 0x19743224, 0x00000000
  /* Layer 7 - 1 */
  .word 0x014eab2e, 0x00000000
  .word 0xd4522112, 0x00000000
  .word 0x2cd52aae, 0x00000000
  .word 0xcbb540d4, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 2 */
  .word 0xbc2c9a1c, 0x00000000
  /* Layer 6 - 2 */
  .word 0xfa27d58e, 0x00000000
  .word 0x87094e0e, 0x00000000
  /* Layer 7 - 2 */
  .word 0x7de29fcd, 0x00000000
  .word 0x379942fb, 0x00000000
  .word 0xaff27732, 0x00000000
  .word 0x54970814, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 3 */
  .word 0x66f8144e, 0x00000000
  /* Layer 6 - 3 */
  .word 0x5c0c9c92, 0x00000000
  .word 0xb12d72a9, 0x00000000
  /* Layer 7 - 3 */
  .word 0x6c5a2074, 0x00000000
  .word 0xccb52d24, 0x00000000
  .word 0xfc4f0d9d, 0x00000000
  .word 0x11eaedee, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 4 */
  .word 0x71811d74, 0x00000000
  /* Layer 6 - 4 */
  .word 0xaf19ea51, 0x00000000
  .word 0x9e078945, 0x00000000
  /* Layer 7 - 4 */
  .word 0x3a22e9a0, 0x00000000
  .word 0xa5cbdca1, 0x00000000
  .word 0xe7da790b, 0x00000000
  .word 0xea8b7f1e, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 5 */
  .word 0xea3cc040, 0x00000000
  /* Layer 6 - 5 */
  .word 0x31fc27af, 0x00000000
  .word 0x9807ff63, 0x00000000
  /* Layer 7 - 5 */
  .word 0x82f5ed16, 0x00000000
  .word 0x7ef63bd5, 0x00000000
  .word 0xd6795921, 0x00000000
  .word 0x8992f4b3, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 6 */
  .word 0x044e701f, 0x00000000
  /* Layer 6 - 6 */
  .word 0xc13fe765, 0x00000000
  .word 0x3099ccc9, 0x00000000
  /* Layer 7 - 6 */
  .word 0x8e08c440, 0x00000000
  .word 0x4935720b, 0x00000000
  .word 0x7059d1b5, 0x00000000
  .word 0xcea1560e, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 7 */
  .word 0xac4184cf, 0x00000000
  /* Layer 6 - 7 */
  .word 0xdc518394, 0x00000000
  .word 0x0289a6a5, 0x00000000
  /* Layer 7 - 7 */
  .word 0x483585bb, 0x00000000
  .word 0xb17c3187, 0x00000000
  .word 0xbb67bcf2, 0x00000000
  .word 0xb7a31ad7, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 8 */
  .word 0x6681f601, 0x00000000
  /* Layer 6 - 8 */
  .word 0x658209b1, 0x00000000
  .word 0x934370f8, 0x00000000
  /* Layer 7 - 8 */
  .word 0x385e2025, 0x00000000
  .word 0xb3b7194d, 0x00000000
  .word 0x149bf401, 0x00000000
  .word 0x314afa3c, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 9 */
  .word 0x6da8cba2, 0x00000000
  /* Layer 6 - 9 */
  .word 0xb254be68, 0x00000000
  .word 0x6e59f915, 0x00000000
  /* Layer 7 - 9 */
  .word 0x79cf3ed4, 0x00000000
  .word 0xb0b7545c, 0x00000000
  .word 0x9ca52e5f, 0x00000000
  .word 0xf79e2ee9, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 10 */
  .word 0xa1074e36, 0x00000000
  /* Layer 6 - 10 */
  .word 0x3e0eeb29, 0x00000000
  .word 0x22c23fd4, 0x00000000
  /* Layer 7 - 10 */
  .word 0x1cd665aa, 0x00000000
  .word 0xc4049d2f, 0x00000000
  .word 0xa0b88f58, 0x00000000
  .word 0x7e801d88, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 11 */
  .word 0x2924384b, 0x00000000
  /* Layer 6 - 11 */
  .word 0x6e95083b, 0x00000000
  .word 0xdc8c92ba, 0x00000000
  /* Layer 7 - 11 */
  .word 0x51bea292, 0x00000000
  .word 0x1887f58b, 0x00000000
  .word 0xd53e5dab, 0x00000000
  .word 0x3a369957, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 12 */
  .word 0xdda02ec2, 0x00000000
  /* Layer 6 - 12 */
  .word 0x75f6ed02, 0x00000000
  .word 0xb8b6b6df, 0x00000000
  /* Layer 7 - 12 */
  .word 0xa169bccb, 0x00000000
  .word 0x2b2410ec, 0x00000000
  .word 0xbda2a4b9, 0x00000000
  .word 0xc77a806d, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 13 */
  .word 0xb805896c, 0x00000000
  /* Layer 6 - 13 */
  .word 0xcb8de165, 0x00000000
  .word 0xc93f49e7, 0x00000000
  /* Layer 7 - 13 */
  .word 0xd7a0a4e0, 0x00000000
  .word 0x53f98a58, 0x00000000
  .word 0x1efd9db9, 0x00000000
  .word 0x4ee63d0f, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 14 */
  .word 0xdd651f9c, 0x00000000
  /* Layer 6 - 14 */
  .word 0x71e38c09, 0x00000000
  .word 0x31d4c840, 0x00000000
  /* Layer 7 - 14 */
  .word 0x57e58be2, 0x00000000
  .word 0xa555be54, 0x00000000
  .word 0xd565bd19, 0x00000000
  .word 0x442224c3, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 15 */
  .word 0x97ccf03d, 0x00000000
  /* Layer 6 - 15 */
  .word 0xbe402274, 0x00000000
  .word 0xef28ae1a, 0x00000000
  /* Layer 7 - 15 */
  .word 0x846bf7b2, 0x00000000
  .word 0x5d33e851, 0x00000000
  .word 0x901c4c98, 0x00000000
  .word 0x4f214c36, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 5 - 16 */
  .word 0x3f228731, 0x00000000
  /* Layer 6 - 16 */
  .word 0x5e5b3410, 0x00000000
  .word 0x45fa9df4, 0x00000000
  /* Layer 7 - 16 */
  .word 0xa24249ac, 0x00000000
  .word 0xe1b38fba, 0x00000000
  .word 0x440e750b, 0x00000000
  .word 0xa5a47d32, 0x00000000
  .word 0x00000000, 0x00000000

.globl twiddles_intt_base
twiddles_intt_base:
  /* Layer 7 - 1 */
  .word 0x5a5b82cf, 0x00000000
  .word 0xbbf18af6, 0x00000000
  .word 0x1e4c7047, 0x00000000
  .word 0x5dbdb655, 0x00000000
  /* Layer 6 - 1 */
  .word 0xba05620d, 0x00000000
  .word 0xa1a4cbf1, 0x00000000
  /* Layer 5 - 1 */
  .word 0xc0dd78d0, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 2 */
  .word 0xb0deb3cb, 0x00000000
  .word 0x6fe3b369, 0x00000000
  .word 0xa2cc17b0, 0x00000000
  .word 0x7b94084f, 0x00000000
  /* Layer 6 - 2 */
  .word 0x10d751e7, 0x00000000
  .word 0x41bfdd8d, 0x00000000
  /* Layer 5 - 2 */
  .word 0x68330fc4, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 3 */
  .word 0xbbdddb3e, 0x00000000
  .word 0x2a9a42e8, 0x00000000
  .word 0x5aaa41ad, 0x00000000
  .word 0xa81a741f, 0x00000000
  /* Layer 6 - 3 */
  .word 0xce2b37c1, 0x00000000
  .word 0x8e1c73f8, 0x00000000
  /* Layer 5 - 3 */
  .word 0x229ae065, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 4 */
  .word 0xb119c2f2, 0x00000000
  .word 0xe1026248, 0x00000000
  .word 0xac0675a9, 0x00000000
  .word 0x285f5b21, 0x00000000
  /* Layer 6 - 4 */
  .word 0x36c0b61a, 0x00000000
  .word 0x34721e9c, 0x00000000
  /* Layer 5 - 4 */
  .word 0x47fa7695, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 5 */
  .word 0x38857f94, 0x00000000
  .word 0x425d5b48, 0x00000000
  .word 0xd4dbef15, 0x00000000
  .word 0x5e964336, 0x00000000
  /* Layer 6 - 5 */
  .word 0x47494922, 0x00000000
  .word 0x8a0912ff, 0x00000000
  /* Layer 5 - 5 */
  .word 0x225fd13f, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 6 */
  .word 0xc5c966aa, 0x00000000
  .word 0x2ac1a256, 0x00000000
  .word 0xe7780a76, 0x00000000
  .word 0xae415d6f, 0x00000000
  /* Layer 6 - 6 */
  .word 0x23736d47, 0x00000000
  .word 0x916af7c6, 0x00000000
  /* Layer 5 - 6 */
  .word 0xd6dbc7b6, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 7 */
  .word 0x817fe279, 0x00000000
  .word 0x5f4770a9, 0x00000000
  .word 0x3bfb62d2, 0x00000000
  .word 0xe3299a57, 0x00000000
  /* Layer 6 - 7 */
  .word 0xdd3dc02d, 0x00000000
  .word 0xc1f114d8, 0x00000000
  /* Layer 5 - 7 */
  .word 0x5ef8b1cb, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 8 */
  .word 0x0861d118, 0x00000000
  .word 0x635ad1a2, 0x00000000
  .word 0x4f48aba5, 0x00000000
  .word 0x8630c12d, 0x00000000
  /* Layer 6 - 8 */
  .word 0x91a606ec, 0x00000000
  .word 0x4dab4199, 0x00000000
  /* Layer 5 - 8 */
  .word 0x9257345f, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 9 */
  .word 0xceb505c5, 0x00000000
  .word 0xeb640c00, 0x00000000
  .word 0x4c48e6b4, 0x00000000
  .word 0xc7a1dfdc, 0x00000000
  /* Layer 6 - 9 */
  .word 0x6cbc8f09, 0x00000000
  .word 0x9a7df650, 0x00000000
  /* Layer 5 - 9 */
  .word 0x997e0a00, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 10 */
  .word 0x485ce52a, 0x00000000
  .word 0x4498430f, 0x00000000
  .word 0x4e83ce7a, 0x00000000
  .word 0xb7ca7a46, 0x00000000
  /* Layer 6 - 10 */
  .word 0xfd76595c, 0x00000000
  .word 0x23ae7c6d, 0x00000000
  /* Layer 5 - 10 */
  .word 0x53be7b32, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 11 */
  .word 0x315ea9f3, 0x00000000
  .word 0x8fa62e4c, 0x00000000
  .word 0xb6ca8df6, 0x00000000
  .word 0x71f73bc1, 0x00000000
  /* Layer 6 - 11 */
  .word 0xcf663338, 0x00000000
  .word 0x3ec0189c, 0x00000000
  /* Layer 5 - 11 */
  .word 0xfbb18fe2, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 12 */
  .word 0x766d0b4e, 0x00000000
  .word 0x2986a6e0, 0x00000000
  .word 0x8109c42c, 0x00000000
  .word 0x7d0a12eb, 0x00000000
  /* Layer 6 - 12 */
  .word 0x67f8009e, 0x00000000
  .word 0xce03d852, 0x00000000
  /* Layer 5 - 12 */
  .word 0x15c33fc1, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 13 */
  .word 0x157480e3, 0x00000000
  .word 0x182586f6, 0x00000000
  .word 0x5a342360, 0x00000000
  .word 0xc5dd1661, 0x00000000
  /* Layer 6 - 13 */
  .word 0x61f876bc, 0x00000000
  .word 0x50e615b0, 0x00000000
  /* Layer 5 - 13 */
  .word 0x8e7ee28d, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 14 */
  .word 0xee151213, 0x00000000
  .word 0x03b0f264, 0x00000000
  .word 0x334ad2dd, 0x00000000
  .word 0x93a5df8d, 0x00000000
  /* Layer 6 - 14 */
  .word 0x4ed28d58, 0x00000000
  .word 0xa3f3636f, 0x00000000
  /* Layer 5 - 14 */
  .word 0x9907ebb3, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 15 */
  .word 0xab68f7ed, 0x00000000
  .word 0x500d88cf, 0x00000000
  .word 0xc866bd06, 0x00000000
  .word 0x821d6034, 0x00000000
  /* Layer 6 - 15 */
  .word 0x78f6b1f3, 0x00000000
  .word 0x05d82a73, 0x00000000
  /* Layer 5 - 15 */
  .word 0x43d365e5, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 7 - 16 */
  .word 0x344abf2d, 0x00000000
  .word 0xd32ad553, 0x00000000
  .word 0x2baddeef, 0x00000000
  .word 0xfeb154d3, 0x00000000
  /* Layer 6 - 16 */
  .word 0xe68bcddd, 0x00000000
  .word 0xe9c6a1f4, 0x00000000
  /* Layer 5 - 16 */
  .word 0xe93cd3f0, 0x00000000
  .word 0x00000000, 0x00000000
  /* Layer 4--1 */ 
  .word 0x79bb8f1d, 0x00000000
  .word 0xd43e715a, 0x00000000
  .word 0x054e5c70, 0x00000000
  .word 0x29c1b606, 0x00000000
  .word 0xc2b5f202, 0x00000000
  .word 0xf12886bb, 0x00000000
  .word 0x6c6dd02c, 0x00000000
  .word 0xae550d27, 0x00000000
  .word 0xbec9f078, 0x00000000
  .word 0x6e1ee9ef, 0x00000000
  .word 0xcf8d92a6, 0x00000000
  .word 0x34d48d31, 0x00000000
  .word 0x031374a9, 0x00000000
  .word 0x39991b9c, 0x00000000
  .word 0x6b6de3db, 0x00000000
  /* n_inv */ 
  .word 0x912fe8a0, 0x00000000

.globl twiddles_basemul_base
twiddles_basemul_base:
  /* basemul -- 1 */
  .word 0x014eab2e, 0x00000000
  .word 0xd4522112, 0x00000000
  .word 0x2cd52aae, 0x00000000
  .word 0xcbb540d4, 0x00000000
  /* basemul -- 2 */
  .word 0x7de29fcd, 0x00000000
  .word 0x379942fb, 0x00000000
  .word 0xaff27732, 0x00000000
  .word 0x54970814, 0x00000000
  /* basemul -- 3 */
  .word 0x6c5a2074, 0x00000000
  .word 0xccb52d24, 0x00000000
  .word 0xfc4f0d9d, 0x00000000
  .word 0x11eaedee, 0x00000000
  /* basemul -- 4 */
  .word 0x3a22e9a0, 0x00000000
  .word 0xa5cbdca1, 0x00000000
  .word 0xe7da790b, 0x00000000
  .word 0xea8b7f1e, 0x00000000
  /* basemul -- 5 */
  .word 0x82f5ed16, 0x00000000
  .word 0x7ef63bd5, 0x00000000
  .word 0xd6795921, 0x00000000
  .word 0x8992f4b3, 0x00000000
  /* basemul -- 6 */
  .word 0x8e08c440, 0x00000000
  .word 0x4935720b, 0x00000000
  .word 0x7059d1b5, 0x00000000
  .word 0xcea1560e, 0x00000000
  /* basemul -- 7 */
  .word 0x483585bb, 0x00000000
  .word 0xb17c3187, 0x00000000
  .word 0xbb67bcf2, 0x00000000
  .word 0xb7a31ad7, 0x00000000
  /* basemul -- 8 */
  .word 0x385e2025, 0x00000000
  .word 0xb3b7194d, 0x00000000
  .word 0x149bf401, 0x00000000
  .word 0x314afa3c, 0x00000000
  /* basemul -- 9 */
  .word 0x79cf3ed4, 0x00000000
  .word 0xb0b7545c, 0x00000000
  .word 0x9ca52e5f, 0x00000000
  .word 0xf79e2ee9, 0x00000000
  /* basemul -- 10 */
  .word 0x1cd665aa, 0x00000000
  .word 0xc4049d2f, 0x00000000
  .word 0xa0b88f58, 0x00000000
  .word 0x7e801d88, 0x00000000
  /* basemul -- 11 */
  .word 0x51bea292, 0x00000000
  .word 0x1887f58b, 0x00000000
  .word 0xd53e5dab, 0x00000000
  .word 0x3a369957, 0x00000000
  /* basemul -- 12 */
  .word 0xa169bccb, 0x00000000
  .word 0x2b2410ec, 0x00000000
  .word 0xbda2a4b9, 0x00000000
  .word 0xc77a806d, 0x00000000
  /* basemul -- 13 */
  .word 0xd7a0a4e0, 0x00000000
  .word 0x53f98a58, 0x00000000
  .word 0x1efd9db9, 0x00000000
  .word 0x4ee63d0f, 0x00000000
  /* basemul -- 14 */
  .word 0x57e58be2, 0x00000000
  .word 0xa555be54, 0x00000000
  .word 0xd565bd19, 0x00000000
  .word 0x442224c3, 0x00000000
  /* basemul -- 15 */
  .word 0x846bf7b2, 0x00000000
  .word 0x5d33e851, 0x00000000
  .word 0x901c4c98, 0x00000000
  .word 0x4f214c36, 0x00000000
  /* basemul -- 16 */
  .word 0xa24249ac, 0x00000000
  .word 0xe1b38fba, 0x00000000
  .word 0x440e750b, 0x00000000
  .word 0xa5a47d32, 0x00000000

.globl context
context:
  .balign 32
  .zero 212

.globl rc
.balign 32
rc:
  .balign 32
  .dword 0x0000000000000001
  .balign 32
  .dword 0x0000000000008082
  .balign 32
  .dword 0x800000000000808a
  .balign 32
  .dword 0x8000000080008000
  .balign 32
  .dword 0x000000000000808b
  .balign 32
  .dword 0x0000000080000001
  .balign 32
  .dword 0x8000000080008081
  .balign 32
  .dword 0x8000000000008009
  .balign 32
  .dword 0x000000000000008a
  .balign 32
  .dword 0x0000000000000088
  .balign 32
  .dword 0x0000000080008009
  .balign 32
  .dword 0x000000008000000a
  .balign 32
  .dword 0x000000008000808b
  .balign 32
  .dword 0x800000000000008b
  .balign 32
  .dword 0x8000000000008089
  .balign 32
  .dword 0x8000000000008003
  .balign 32
  .dword 0x8000000000008002
  .balign 32
  .dword 0x8000000000000080
  .balign 32
  .dword 0x000000000000800a
  .balign 32
  .dword 0x800000008000000a
  .balign 32
  .dword 0x8000000080008081
  .balign 32
  .dword 0x8000000000008080
  .balign 32
  .dword 0x0000000080000001
  .balign 32
  .dword 0x8000000080008008