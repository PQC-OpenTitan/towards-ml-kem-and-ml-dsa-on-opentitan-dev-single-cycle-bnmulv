# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import struct
from typing import List, Tuple
from hw.ip.otbn.util.otbn_sim_py import run_sim

def key_pair_otbn(zeta: bytes, operation: str) -> Tuple[bytes, bytes]:
    if "dilithium2" in operation:
        CRYPTO_PUBLICKEYBYTES = (32 + 4*320)
        CRYPTO_SECRETKEYBYTES = (2*32 + 64 + 4*96 + 4*96 + 4*416)
        CRYPTO_BYTES = (32 + 4*576 + (80 + 4))
    elif "dilithium3" in operation:
        CRYPTO_PUBLICKEYBYTES = 1952
        CRYPTO_SECRETKEYBYTES = 4032
        CRYPTO_BYTES = 3309
    elif "dilithium5" in operation:
        CRYPTO_PUBLICKEYBYTES = 2592
        CRYPTO_SECRETKEYBYTES = 4896
        CRYPTO_BYTES = 4627
    STACK_SIZE = 112000
    # skip the first 8 bytes (=model, op_state)
    _, raw_dmem, stat_data = run_sim(operation,
                                     [(STACK_SIZE + CRYPTO_PUBLICKEYBYTES + CRYPTO_SECRETKEYBYTES, zeta)])

    pk = raw_dmem[STACK_SIZE:STACK_SIZE + CRYPTO_PUBLICKEYBYTES]
    sk = raw_dmem[STACK_SIZE + CRYPTO_PUBLICKEYBYTES:STACK_SIZE + CRYPTO_PUBLICKEYBYTES + CRYPTO_SECRETKEYBYTES]

    return pk, sk, stat_data


def verify_otbn(pk_bytes: bytes, m: bytes, sig_bytes: bytes, operation: str) -> int:
    if "dilithium2" in operation:
        CRYPTO_PUBLICKEYBYTES = (32 + 4*320)
        CRYPTO_SECRETKEYBYTES = (2*32 + 64 + 4*96 + 4*96 + 4*416)
        CRYPTO_BYTES = (32 + 4*576 + (80 + 4))
    elif "dilithium3" in operation:
        CRYPTO_PUBLICKEYBYTES = 1952
        CRYPTO_SECRETKEYBYTES = 4032
        CRYPTO_BYTES = 3309
    elif "dilithium5" in operation:
        CRYPTO_PUBLICKEYBYTES = 2592
        CRYPTO_SECRETKEYBYTES = 4896
        CRYPTO_BYTES = 4627
    STACK_SIZE = 112000
    # skip the first 8 bytes (=model, op_state)
    # account for alignment of message
    pk_addr = STACK_SIZE
    sig_addr = pk_addr + CRYPTO_PUBLICKEYBYTES
    if "dilithium3" in operation:
        sig_addr += 16
    m_addr = sig_addr + CRYPTO_BYTES
    from math import ceil
    m_addr = int(ceil(m_addr / 32) * 32)  # align
    m_len_addr = m_addr + 9 * 4 + 3300
    m_len_bytes = len(m).to_bytes(4, "little")
    regs, _, stat_data = run_sim(operation, [(pk_addr, pk_bytes),
                                                (sig_addr, sig_bytes),
                                                (m_addr, m),
                                                (m_len_addr, m_len_bytes)])

    print(regs)

    # a0 is 0 on success, -1 on fail
    return regs["x10"] == 0, stat_data


def sign_otbn(sk_bytes: bytes, m: bytes, operation: str) -> int:
    # skip the first 8 bytes (=model, op_state)
    # account for alignment of message
    if "dilithium2" in operation:
        CRYPTO_PUBLICKEYBYTES = (32 + 4*320)
        CRYPTO_SECRETKEYBYTES = (2*32 + 64 + 4*96 + 4*96 + 4*416)
        CRYPTO_BYTES = (32 + 4*576 + (80 + 4))
        STACK_SIZE = 51200
        SK_ADDR = 2528 + (2420 + 12) + 17408
        SIG_ADDR = 2528
    elif "dilithium3" in operation:
        CRYPTO_PUBLICKEYBYTES = 1952
        CRYPTO_SECRETKEYBYTES = 4032
        CRYPTO_BYTES = 3309
        STACK_SIZE = 78848
        SK_ADDR = 2656 + (16 + 3309 + 3) + 24576
        SIG_ADDR = 2656 + 16
    elif "dilithium5" in operation:
        CRYPTO_PUBLICKEYBYTES = 2592
        CRYPTO_SECRETKEYBYTES = 4896
        CRYPTO_BYTES = 4627
        STACK_SIZE = 120832
        SK_ADDR = 2368 + (4627 + 13) + 32768
        SIG_ADDR = 2368
    sk_addr = SK_ADDR
    sig_addr = SIG_ADDR
    m_addr = sk_addr + CRYPTO_SECRETKEYBYTES
    m_len_addr = m_addr + 3196
    m_len_bytes = len(m).to_bytes(4, "little")
    print(f"m_len_addr {m_len_addr}")
    print(f"m_len_bytes {m_len_bytes.hex()}")
    regs, raw_dmem, stat_data = run_sim(operation, [(sk_addr, sk_bytes),
                                                (m_addr, m),
                                                (m_len_addr, m_len_bytes)])
    sig = raw_dmem[sig_addr:sig_addr+CRYPTO_BYTES]

    print(regs)

    # sig, 0, siglen
    return sig, regs["x10"], regs["x11"], stat_data
