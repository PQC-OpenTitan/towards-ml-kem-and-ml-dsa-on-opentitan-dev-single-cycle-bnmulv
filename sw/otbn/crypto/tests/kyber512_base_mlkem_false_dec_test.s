/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */


/*
 * Test for kyber512_base_mlkem_false_dec
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
/* First input: randombytes */
ct:
  .word 0xdfd6dfba
  .word 0xa559c3aa
  .word 0xcc7bbbef
  .word 0x38d5594b
  .word 0x30049adf
  .word 0xbcc8102e
  .word 0x0b1abf1c
  .word 0xea20513a
  .word 0xcfa7cd17
  .word 0x565f76ad
  .word 0x364d4723
  .word 0xafa8cc8c
  .word 0x9fcd0700
  .word 0x9f844c5e
  .word 0x0b587a16
  .word 0xefbdaa14
  .word 0xf4eee7ae
  .word 0xa9fcb07c
  .word 0xfde17b76
  .word 0xdf1994a6
  .word 0xdfe927b9
  .word 0x198b3407
  .word 0xaeab9166
  .word 0x2db380b5
  .word 0x8b5358ef
  .word 0x77f8238d
  .word 0xb063ea32
  .word 0xf4a04f2b
  .word 0xe2603387
  .word 0xcd281984
  .word 0xee4cdd60
  .word 0xc9d4c08c
  .word 0x8861a922
  .word 0x5c6732d0
  .word 0x9350c88a
  .word 0x15ff7a3c
  .word 0x834cb933
  .word 0x9cb6db4a
  .word 0xd4ba1561
  .word 0x19862d69
  .word 0xdf0c0bf9
  .word 0x269c7b8a
  .word 0x18ac2940
  .word 0x3fb8705b
  .word 0xf4f20128
  .word 0x590cf7b3
  .word 0xebaea33e
  .word 0x1b7f3a61
  .word 0xd73fe31d
  .word 0x92f58150
  .word 0x452e5f30
  .word 0x96c0ed26
  .word 0x5809b131
  .word 0x89d864f4
  .word 0x10a01bf3
  .word 0x7fda0f25
  .word 0x29ec6813
  .word 0xef84fc67
  .word 0xf2afe92a
  .word 0x70b1e068
  .word 0x82c6ff0a
  .word 0x3d3a520b
  .word 0xf2357191
  .word 0x06eef2df
  .word 0x312be7bf
  .word 0x4a1d7224
  .word 0x534ec026
  .word 0xe7305ea7
  .word 0x4a9c7a3a
  .word 0x551cd995
  .word 0xf5e995d4
  .word 0xe9b5d01d
  .word 0x5e6d3cd8
  .word 0xaa03e88c
  .word 0x54d6b862
  .word 0x9bd053db
  .word 0x73f2cf8d
  .word 0x73b5fecd
  .word 0xd4bcd8fa
  .word 0xc2be7855
  .word 0x1ed070e7
  .word 0x726ee8fd
  .word 0x6c7c3f1a
  .word 0xab5d27ce
  .word 0x3f14e2e6
  .word 0xa78df11a
  .word 0xc7c4ddef
  .word 0x345e0bb7
  .word 0xc93cb95d
  .word 0x23a3be36
  .word 0x38cb1c49
  .word 0x46f588a3
  .word 0xdd00ffa9
  .word 0xb900134e
  .word 0x203d15b2
  .word 0xb405d241
  .word 0x451be443
  .word 0xa5f253a6
  .word 0x1a2c49c4
  .word 0x124554dd
  .word 0x9852a2dd
  .word 0x712b4633
  .word 0xbe451aa4
  .word 0x6f0b2997
  .word 0x2cdaff4c
  .word 0x160590f9
  .word 0xedb1a434
  .word 0xb44f11f6
  .word 0xfac18390
  .word 0xe02e303b
  .word 0x2651f097
  .word 0xc79de66b
  .word 0xf9eefd16
  .word 0xb24a0d1b
  .word 0x505552de
  .word 0x8adc80bf
  .word 0xb5c34b68
  .word 0x7e6bd4a4
  .word 0xdcafe7fa
  .word 0x8d989262
  .word 0x03aeacc9
  .word 0x864463f8
  .word 0x78e2abc1
  .word 0x024cae1a
  .word 0x2c0d46f3
  .word 0x63a4e6d4
  .word 0x6295baa2
  .word 0xf03c62ee
  .word 0xb42af8e9
  .word 0xd0c9b5d0
  .word 0x3669a240
  .word 0xf0df7964
  .word 0xafbf8a03
  .word 0x1ff20f2e
  .word 0x72899636
  .word 0xdd04f1e3
  .word 0x83ebe1cb
  .word 0x13c2871a
  .word 0xb3292e16
  .word 0x64a5df4a
  .word 0xf6e921d1
  .word 0x429f72e7
  .word 0x6c5cfc03
  .word 0x737afa22
  .word 0xb6ddaf50
  .word 0x4a3a9220
  .word 0xcb8a9b12
  .word 0xf810ea19
  .word 0x3b0ec318
  .word 0x1f571c5b
  .word 0xee579ea7
  .word 0x31884330
  .word 0xd9fc026a
  .word 0xe08e0d3a
  .word 0x0157b82b
  .word 0x97f04fee
  .word 0x2c504b53
  .word 0xb9fb121b
  .word 0x2fcb8c5c
  .word 0xd9218954
  .word 0xfec9c79c
  .word 0x1b99ac17
  .word 0x11635e67
  .word 0xef3e4244
  .word 0x1669587a
  .word 0x1f3da68d
  .word 0x50f6214c
  .word 0xbf2329c0
  .word 0x6aca96d3
  .word 0x0641b55d
  .word 0xc5cb2486
  .word 0xc008e2ff
  .word 0x1a4ea7d1
  .word 0x0b8d6129
  .word 0xf53600b6
  .word 0xa8bf9a24
  .word 0x93e39888
  .word 0xfa6e8d71
  .word 0x12b45bb0
  .word 0x4ccdef79
  .word 0x37c80c5a
  .word 0xbe22fccc
  .word 0x085c724f
  .word 0x90a06a1f
  .word 0x70ba9d74
  .word 0xd4e8ba77
  .word 0xc5fef31a
  .word 0x8a1beea6
  .word 0x725ed2dc
  .word 0x454336de
  .word 0x7c56ef84
  .word 0x42343d64

sk:
  .word 0x8d53bc3c
  .word 0xea2c54a4
  .word 0x6a19a283
  .word 0x6e2f2c1d
  .word 0x32d0cedb
  .word 0x13c1f1b2
  .word 0xc20190d4
  .word 0x93a28081
  .word 0x6663b890
  .word 0x169967d6
  .word 0xc40bca98
  .word 0xb4f9840e
  .word 0x313bc1d3
  .word 0x70a58529
  .word 0xb5962a85
  .word 0x86a0fc90
  .word 0x8740b506
  .word 0xbeb04623
  .word 0x781c3cda
  .word 0xa6f38d92
  .word 0x72845799
  .word 0x5e32d4df
  .word 0xeac3bd48
  .word 0x04f5d633
  .word 0x5471f4a1
  .word 0x8b7e9a3a
  .word 0x86763fbd
  .word 0xbbadbc13
  .word 0x11f3bbeb
  .word 0x91c80237
  .word 0x4625796f
  .word 0xf8d37b4c
  .word 0xadc104c8
  .word 0xaf7d230d
  .word 0x73daca45
  .word 0xace4b53e
  .word 0xcbc7f49b
  .word 0x7293c13b
  .word 0xca9a71b3
  .word 0x0a7411f6
  .word 0xd539a210
  .word 0x2dba21a8
  .word 0x3f952a7b
  .word 0x788e70cc
  .word 0x48a069a8
  .word 0xe191a312
  .word 0xa86f77f2
  .word 0x2c630e53
  .word 0xd572f7e8
  .word 0x786b2f33
  .word 0x1fb88d31
  .word 0x3a2f824c
  .word 0xa2bd6103
  .word 0x35054d58
  .word 0x76939b24
  .word 0xd38290f0
  .word 0x52b24a08
  .word 0x527890c8
  .word 0x34af8f02
  .word 0xc3a93196
  .word 0xc187808f
  .word 0x05fdba8b
  .word 0x641b08b9
  .word 0xbf3cd365
  .word 0x325e4913
  .word 0x33a52379
  .word 0x9a7f2722
  .word 0x9541c90c
  .word 0x4786cb2c
  .word 0x15795032
  .word 0x6a636e0a
  .word 0x27a14eb0
  .word 0xac3b8b36
  .word 0x700e5f7a
  .word 0xbd43ce1f
  .word 0xb95edb52
  .word 0xe2a65c48
  .word 0xaa6c9a4d
  .word 0xb03efb39
  .word 0x474e8669
  .word 0xb4394e15
  .word 0xbcb3771b
  .word 0xfa099bc3
  .word 0x5517a28a
  .word 0x0d763c50
  .word 0x391c9844
  .word 0x5c7957ce
  .word 0x4d9be63c
  .word 0x36d05f80
  .word 0x0663f22e
  .word 0xa870104b
  .word 0x917941fa
  .word 0x3de5875b
  .word 0x19c190d0
  .word 0x6866a935
  .word 0x57c49216
  .word 0xf99645c2
  .word 0x7bf58e31
  .word 0x56909101
  .word 0x59b020a0
  .word 0x603abfb7
  .word 0x13d01480
  .word 0x387bb29f
  .word 0x0a989d19
  .word 0x9298a19c
  .word 0x54bb9656
  .word 0xeade9390
  .word 0x06ca565e
  .word 0xe958890c
  .word 0x5732cd13
  .word 0x939138ca
  .word 0x658c4a7b
  .word 0xb66f21e8
  .word 0x4ea31049
  .word 0x02998646
  .word 0x556959bb
  .word 0x6f364b1a
  .word 0xe87d16f4
  .word 0xe303ca38
  .word 0x290726c1
  .word 0xfa36bbcc
  .word 0xe1c0ae34
  .word 0xb8e1b714
  .word 0xb44c82cb
  .word 0x76009c59
  .word 0xb052cd6b
  .word 0x3385c13a
  .word 0x7891c563
  .word 0x8fe5f347
  .word 0x04794b11
  .word 0x4c6065cb
  .word 0x28488537
  .word 0x793729df
  .word 0x283a074c
  .word 0xbab159c8
  .word 0x1db77ab2
  .word 0xda9e71b4
  .word 0xb3b0940c
  .word 0x74b57aa3
  .word 0xa4586596
  .word 0xae946796
  .word 0x06702427
  .word 0x706bb087
  .word 0xa6e8fd64
  .word 0x053111b8
  .word 0x16f5cde8
  .word 0x9c637b6e
  .word 0xbfc299d7
  .word 0x14c9bc20
  .word 0x5460813e
  .word 0xcca727c3
  .word 0x29ad0df6
  .word 0x9b228457
  .word 0x639b25e8
  .word 0xcc6d091c
  .word 0x11c1d368
  .word 0x38ce3b24
  .word 0x08597bc3
  .word 0x58680341
  .word 0xc63b9647
  .word 0xec726141
  .word 0x9b61f367
  .word 0x55a92954
  .word 0x2306aa8a
  .word 0xad9aec87
  .word 0x6ece7797
  .word 0x99eeacd7
  .word 0x9bc711b6
  .word 0xcb35757c
  .word 0x445d2be3
  .word 0x3e853e02
  .word 0xb4421cd4
  .word 0x8a8ecdf9
  .word 0xb764786e
  .word 0x61b403c1
  .word 0xdc860733
  .word 0x8897ac17
  .word 0x88c6800c
  .word 0x89e69a26
  .word 0xa639b07c
  .word 0x0f3013e6
  .word 0xa6089839
  .word 0xb805dd1f
  .word 0x2e727171
  .word 0xdb475ddb
  .word 0x9a570f52
  .word 0x7a27c6c1
  .word 0x939033f7
  .word 0x050c62ac
  .word 0xd113c83a
  .word 0xf0fe14c6
  .word 0x70c62ccb
  .word 0xbfa7b05a
  .word 0x2bd423c6
  .word 0x26546506
  .word 0xa3b4a782
  .word 0x7783a3b7
  .word 0xcc643b5b
  .word 0xe17040ae
  .word 0x91960565
  .word 0xac61c1b7
  .word 0xfe4d90d0
  .word 0xca800cc1
  .word 0x92ab89ae
  .word 0xc740450b
  .word 0x42bd8925
  .word 0x43921909
  .word 0xf2a0f1fb
  .word 0xfc9da0e7
  .word 0xaed980bf
  .word 0x169df2a3
  .word 0x2b806d3c
  .word 0x87063f85
  .word 0x2232d2e1
  .word 0x741bb3c5
  .word 0x00fa923a
  .word 0xde8d4bc4
  .word 0x30cdc144
  .word 0x430ac767
  .word 0x243e8676
  .word 0xa3d84016
  .word 0x5f7ac61b
  .word 0xaeac86f5
  .word 0x09c6b1d0
  .word 0x2e00af44
  .word 0x8fb3e436
  .word 0xf00123d3
  .word 0xccc53eae
  .word 0xebacf10c
  .word 0x3290be48
  .word 0x3d11d74d
  .word 0x0f64249e
  .word 0x51a69515
  .word 0x161292b2
  .word 0x9d902c1f
  .word 0xd44dbb76
  .word 0xa095048e
  .word 0x3f9a988f
  .word 0xf1a5a2b3
  .word 0x7e545130
  .word 0x4f9a08f4
  .word 0x920669f4
  .word 0x060ce78e
  .word 0x2f383c6c
  .word 0x83ef4f17
  .word 0x1d088e81
  .word 0x2e47697b
  .word 0x7528c223
  .word 0x00e869c2
  .word 0xcb472c76
  .word 0xea9270d9
  .word 0x9940a808
  .word 0x755b53c5
  .word 0xecb99067
  .word 0x51fb1868
  .word 0xf63c27ad
  .word 0xe8590a6b
  .word 0x5140b422
  .word 0x313d43ba
  .word 0x00408089
  .word 0xc462ad36
  .word 0x8d8ca224
  .word 0x794e724c
  .word 0x21e15482
  .word 0xbd483b03
  .word 0x6ac61723
  .word 0xcbca5047
  .word 0x4c758338
  .word 0xdc9ead15
  .word 0xae0b2664
  .word 0x30a78a28
  .word 0x12faabaa
  .word 0x049c7f08
  .word 0x596cec96
  .word 0x48542ec9
  .word 0x19c13f0b
  .word 0x261390fb
  .word 0x39667cc6
  .word 0x45b9f88f
  .word 0xac3543ce
  .word 0xa7123924
  .word 0x4f36e616
  .word 0xe17b1215
  .word 0xf92a5f47
  .word 0x796b1712
  .word 0xa7940b79
  .word 0x46d04d0a
  .word 0x77c12397
  .word 0x35839054
  .word 0x5a2e1354
  .word 0x51328419
  .word 0xab508338
  .word 0x232d8777
  .word 0x972bfd57
  .word 0x039e164b
  .word 0xb92593fc
  .word 0x86f20041
  .word 0x0a1dc559
  .word 0x65f91034
  .word 0x878b6218
  .word 0xcdb3b5e2
  .word 0xb648ae87
  .word 0x4ea5ccb0
  .word 0x60463048
  .word 0x9ae7796a
  .word 0x23018a3e
  .word 0x61ce1835
  .word 0x835026a7
  .word 0x6792b73a
  .word 0xe1ca04fc
  .word 0xf8ba1de7
  .word 0x40d70162
  .word 0x2473e37d
  .word 0xea5b3347
  .word 0x70754b3c
  .word 0x0778309b
  .word 0xc6c9c0db
  .word 0x43783547
  .word 0x2467a7f5
  .word 0xb6e695c3
  .word 0x2035649b
  .word 0x948a5ca4
  .word 0xd69734f8
  .word 0x4e6082aa
  .word 0x3f866397
  .word 0x6ae04399
  .word 0x7ad9db8b
  .word 0x3fa603b7
  .word 0xc7f7566c
  .word 0x4e28e458
  .word 0xfd6c0ba5
  .word 0x6c9411f6
  .word 0x0900356d
  .word 0x055032f2
  .word 0x49da9f94
  .word 0xa7122470
  .word 0x1b156009
  .word 0xf01e3138
  .word 0x3eb4971d
  .word 0x03164292
  .word 0x4a438659
  .word 0x40161d7e
  .word 0x2132615a
  .word 0xc94e302a
  .word 0xa3f0a71d
  .word 0xea1d0ce4
  .word 0x4264b40c
  .word 0x6103dccd
  .word 0xaa7d6a21
  .word 0x07ce3b53
  .word 0x08a9b996
  .word 0x61afdb8a
  .word 0xe01699e7
  .word 0xace68883
  .word 0xc60b03af
  .word 0x2a8877dc
  .word 0x659a7e5e
  .word 0x7cc4978f
  .word 0x86367a6a
  .word 0x53dc43b9
  .word 0x0e191083
  .word 0x682192b4
  .word 0x92209b14
  .word 0x5c824ab9
  .word 0x44b924da
  .word 0x70b26b99
  .word 0x905788b4
  .word 0x84fca149
  .word 0x04fb655b
  .word 0x40330a52
  .word 0x33758317
  .word 0x59a0f1ac
  .word 0xc6b83422
  .word 0x93237969
  .word 0x66bbfe6a
  .word 0xe9ba75dd
  .word 0x581c8deb
  .word 0x75e080ac
  .word 0xc25e5b76
  .word 0x59966333
  .word 0xc894fe1b
  .word 0x540ae0ef
  .word 0xa3370a13
  .word 0x1bd8e5a5
  .word 0xf593fa4c
  .word 0xc722e96e
  .word 0x7b9360d6
  .word 0x07c33759
  .word 0x8f96624d
  .word 0x11126d00
  .word 0x689602c6
  .word 0xdee55359
  .word 0x0d7d58c9
  .word 0x0c0d0363
  .word 0x75e6151c
  .word 0xf9a263ff
  .word 0xba56c1eb
  .word 0xa12d5af1
  .word 0xbe285564
  .word 0x2cacc368
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