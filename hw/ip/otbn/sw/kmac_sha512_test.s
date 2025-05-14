/* Copyright lowRISC contributors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192) */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */


# KMAC test that tests the KMAC application interface between OTBN and KMAC

.section .text

/* KMAC STATUS */
# Bit 0: Done
# Bit 1: Ready
# Bit 2: Error

/* KMAC CFG */
# Bit 0 - 1:  SHA3 Mode:
#  'b00: SHA3
#  'b10: Shake
#  'b11: CShake
# Bit 2 - 4:  Keccak Strength:
#  'b000: L128
#  'b001: L224
#  'b010: L256
#  'b011: L384
#  'b100: L512
# Bit 5 - 7:  Message Length Bytes 
# Bit 8 - 15: Message Length in 64-bit words

li x23, 16      # msg len
li x5, 16       # kmac mode: SHA3-512 - 0b10000

slli x6, x23, 5
or x5, x5, x6

csrrw x0, 0x7d9, x5

# Wait till KMAC is ready
li x5, 2
wait_kmac_ready:
    csrrs x6, 0x7e2, x0
    and x6, x6, x5
    bne x6, x5, wait_kmac_ready

# Write to KMAC MSG reg
li x5, 0
li x6, 0
bn.lid x6, 0(x5)
bn.wsrw 0x9, w0

# Read KMAC DIGEST 2 times for 512-bit digest
bn.wsrr w2, 0xA
bn.wsrr w3, 0xB

bn.wsrr w2, 0xA
bn.wsrr w3, 0xB

ecall


.section .data

.word 0x9d34f3a9
.word 0xe425c5d3
.word 0x1f7d6396
.word 0xbaceb75f
.word 0x919345bc
.word 0x02cedb6c
.word 0x76c717b8
.word 0x3334c594
.word 0x8ea139eb
.word 0xe3dd3da2
.word 0x4d1f7956
.word 0x38be9bfe
.word 0x61df1982
.word 0x6b391314
.word 0x11d0a7d8
.word 0xb62477a6
.word 0xe4433b3a
.word 0x441b8568
.word 0xd383a4b1
.word 0x77f6560d
.word 0xdef5a571
.word 0x63be43f1
.word 0x73434af8
.word 0x810c943f
.word 0xf2db034f
.word 0xda91177f
.word 0xce833a2a
.word 0xa1a56e68
.word 0x6e3a0473
.word 0xd7514c87
.word 0x42e5dba7
.word 0xfce18c4f
.word 0xd71ab3d3
.word 0xce8c38f0
.word 0x518917b4
.word 0x80eec339
.word 0x128479e7
.word 0x137c4342
.word 0x123d5d74
.word 0x0505984e
.word 0x7f3117bc
.word 0x6b87d5e2
.word 0xcf777c50
.word 0xc9becdb2
.word 0x995efd46
.word 0x9fbb1c74
.word 0x660ccb7b
.word 0xbdcc9751
.word 0x70794e4a
.word 0x15821e4b
.word 0xce9ae2cf
.word 0x75561786
.word 0xd0e400d1
.word 0x0d2cd10d
.word 0xff119734
.word 0xff585db1
.word 0x23ac08b6
.word 0xdf29a39c
.word 0x5260024f
.word 0x599e3755
.word 0x4a121e20
.word 0x73c0edff
.word 0x37487ef7
.word 0xf2f1bf3f
.word 0x3c97cae6
.word 0x7e0a5c17
.word 0x9c164dc3
.word 0x622bf937
.word 0xc1f0a7a3
.word 0xb218c503
.word 0xd8638baa
.word 0x12156e97
.word 0xf5de8591
.word 0x53e5c8cf
.word 0x72071cb6
.word 0x8418d0e9
.word 0xc1842093
.word 0x717d66a1
.word 0x040b1fac
.word 0x985ff0b4
.word 0x14c76baa
.word 0x98559c3a
.word 0x9ad7ff48
.word 0xef1d09a9
.word 0x0d2d1053
.word 0x02e481fa
.word 0x4ec39b8c
.word 0x66e15305
.word 0xccf533d7
.word 0xd9d31ceb
.word 0xe5037db0
.word 0xc64b6e90
.word 0x9f7c9eb0
.word 0xb2b7e8cc
.word 0x8965a211
.word 0xbfef0e64
.word 0x724c96ad
.word 0x83c4d228
.word 0xb256bdb7
.word 0xd05c0287
.word 0xf1d9299b
.word 0xc9b49e6b
.word 0x7972787c
.word 0x9bbc1790
.word 0xda5eb5c5
.word 0xb0b143b1
.word 0xc90a9ec3
.word 0x1922c740
.word 0xdc70ecee
.word 0x0ff9cb8e
.word 0xb53f1853
.word 0xde5afd36
.word 0x7aef45e4
.word 0x89b1b064
.word 0x0205665e
.word 0x3c7b3b8f
.word 0x15b0dec2
.word 0xb66f368f
.word 0x6c92cf99
.word 0xb29a003d
.word 0x4e83acd6
.word 0x59928535
.word 0x750f01e4
.word 0x07a92f6c
.word 0xe9af540e
.word 0x2a450231
.word 0x85f890a6
.word 0xa099aa0e
.word 0xcf5127a6
.word 0x68924154
.word 0xec4586b8
.word 0x46e11542
.word 0xd83593e5
.word 0x3da2b57b
.word 0x53080303
.word 0x9efc4075
.word 0x02a08c64
.word 0xd875809c
.word 0x65e1d020
.word 0xa661344f
.word 0x0a8e2d4e
.word 0xed32447f
.word 0x4aab266d
.word 0xa4d7e5f7
.word 0xdee7da0f
.word 0x3ee53ecc
.word 0xa8241e85
.word 0xfe559aa2
.word 0x3ebd3e14
.word 0x00ff4329
.word 0x44509d86
.word 0xf79e943d
.word 0x57deff0c
.word 0x639ddb87
.word 0x56a27ebc
.word 0x53869345
.word 0x2b12fd49
.word 0x5c611fc3
.word 0x5db0c7a9
.word 0x838dd307
.word 0x02719d4f
.word 0xd9ed237d
.word 0x6f89f885
.word 0x4a0c915d
.word 0x52df4d20
.word 0xd6977a80
.word 0x3db894c6
.word 0x985aa11c
.word 0xfd0e64f3
.word 0x18341ec0
.word 0xd44b757c
.word 0xf7288f45
.word 0x38665654
.word 0x7155d835
.word 0xaff4f0c6
.word 0xd92bafc9
.word 0xd1475da0
.word 0x1a0ed19f
.word 0xccb52dd9
.word 0x0c5feb3e
.word 0xfe84a6b3
.word 0x1348899c
.word 0xac456f10
.word 0xdb35c22f
.word 0x7513da12
.word 0x7cb6636c
.word 0xaa4bc558
.word 0x3f60efa1
.word 0xe945c72e
.word 0x381a2237
.word 0x7fcdc600
.word 0x75ef84cc
.word 0x3d677f9e
.word 0xbbc0212d
.word 0xc7854c66
.word 0x7da3060d
.word 0x3f3ace04
.word 0x49e408d0
.word 0xf369026e
.word 0x33983aee
.word 0x087e0713
.word 0xf0f7d031
.word 0x99b065ab
.word 0x0b5ddc89
.word 0xd4292760
.word 0x33fb3c6c
.word 0xb8c7178a
.word 0x08f460f2
.word 0xdbdcf7e5
.word 0xe40ce1e4
.word 0x3347d47a
.word 0x9bb0475f
.word 0x46f97f2f
.word 0x93bbbc9c
.word 0xc6ba759e
.word 0xc5ecfa4e
.word 0x42eab336
.word 0xd017b184
.word 0x19f6edf8
.word 0x352f130a
.word 0x008cf71b
.word 0x29822c05
.word 0x75cc12ef
.word 0x1695bbbd
.word 0x761b7387
.word 0xefc144f4
.word 0x2c07ec3c
.word 0x77839144
.word 0xa6b01d36
.word 0x667c1069
.word 0x3aeeab30
.word 0x9fb0a044
.word 0x21e43dd0
.word 0x8547da53
.word 0x970568b4
.word 0x83972b96
.word 0xb7ba6d64
.word 0x6749cd0a
.word 0x53e181ca
.word 0x283d932e
.word 0x24a756dc
.word 0xd4d946a5
.word 0x78b2492d
.word 0x75389b30
.word 0x700f950b
.word 0x767ac968
.word 0x7dea9a7e
.word 0xc2c5801c
.word 0x823b383e
.word 0x0ef68b18
.word 0x46cf1f70
.word 0xc8c54768
.word 0xf3b86112
.word 0x8569c285
.word 0x8e146e5e
.word 0xd5d12fd9

