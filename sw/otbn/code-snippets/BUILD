# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.


load("//rules:otbn.bzl", "otbn_binary")

package(default_visibility = ["//visibility:public"])

otbn_binary(
    name = "barrett384",
    srcs = [
        "barrett384.s",
    ],
)

otbn_binary(
    name = "err_test",
    srcs = [
        "err_test.s",
    ],
)

otbn_binary(
    name = "loop",
    srcs = [
        "loop.s",
    ],
)

otbn_binary(
    name = "mul256",
    srcs = [
        "mul256.s",
    ],
)

otbn_binary(
    name = "mul384",
    srcs = [
        "mul384.s",
    ],
)

otbn_binary(
    name = "pseudo-ops",
    srcs = [
        "pseudo-ops.s",
    ],
)

otbn_binary(
    name = "solinas384",
    srcs = [
        "solinas384.s",
    ],
)

otbn_binary(
    name = "randomness",
    srcs = [
        "randomness.s",
    ],
)

otbn_binary(
    name = "calc_montgomery_consts",
    srcs = [
        "calc_montgomery_consts.s",
    ],
)

otbn_binary(
    name = "kmac_test",
    srcs = [
        "kmac_test.s",
    ],
)
