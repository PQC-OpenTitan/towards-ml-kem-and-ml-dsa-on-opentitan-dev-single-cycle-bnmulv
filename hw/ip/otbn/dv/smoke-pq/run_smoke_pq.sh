#!/bin/bash
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Runs the OTBN smoke test (builds software, build simulation, runs simulation
# and checks expected output)

echo "############################"
echo "# OTBN PQC Extension Tests #"
echo "############################"

while getopts 'st:' OPTION; do
  case "$OPTION" in
    s)
      echo "You supplied the -s option, skipping verilator build"
      SKIP_VERILATOR_BUILD=1
      ;;
    t)
      MANUAL_TESTS="$OPTARG"
      echo "You selected $MANUAL_TESTS for testing"
      ;;
    ?)
      echo "script usage: ./run_smoke_pq.sh [-t <assembly test>] [-s]" >&2
      exit 1
      ;;
  esac
done

fail() {
  echo >&2 "OTBN SMOKE FAILURE: $*"
  exit 1
}

set -o pipefail
set -e

SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
UTIL_DIR="$(readlink -e "$SCRIPT_DIR/../../../../../util")" || \
  fail "Can't find OpenTitan util dir"

source "$UTIL_DIR/build_consts.sh"

SMOKE_BIN_DIR=$BIN_DIR/otbn/smoke_pq_test
SMOKE_SRC_DIR=$REPO_TOP/hw/ip/otbn/dv/smoke
SMOKE_PQ_SRC_DIR=$REPO_TOP/hw/ip/otbn/dv/smoke_pq
OTBN_SW_SRC_DIR=$REPO_TOP/hw/ip/otbn/sw

mkdir -p $SMOKE_BIN_DIR

OTBN_UTIL=$REPO_TOP/hw/ip/otbn/util

PQC_ISA_TESTS=$(ls "$OTBN_SW_SRC_DIR"/*.s)

if [[ -z "$MANUAL_TESTS" ]]; then
  tests="$PQC_ISA_TESTS"
  echo "No test manually selected, run for all:"
  echo $tests
else
  tests=($MANUAL_TESTS)
  echo "Running test for $tests"
fi

if [[ -z "$SKIP_VERILATOR_BUILD" ]]; then
  echo "Building verilator model ..."
  (cd $REPO_TOP;
   fusesoc --cores-root=. run --target=sim --setup --build \
           lowrisc:ip:otbn_top_sim || fail "HW Sim build failed")
else
  echo "WARNING: skipping verilator build, because you set -s"
fi

RUN_LOG=`mktemp`
readonly RUN_LOG
# shellcheck disable=SC2064 # The RUN_LOG tempfile path should not change
trap "rm -rf $RUN_LOG" EXIT

for testcase in $tests
do
  echo  "===================== Testing $testcase ====================="

  testcase_o=${testcase%.s}.o
  testcase_elf=${testcase%.s}.elf

  $OTBN_UTIL/otbn_as.py -DKYBER_K=1 -o $testcase_o $testcase || \
      fail "Failed to assemble ${testcase}"
  $OTBN_UTIL/otbn_ld.py -o $testcase_elf $testcase_o || \
      fail "Failed to link ${testcase_o}"

  timeout 30s \
    $REPO_TOP/build/lowrisc_ip_otbn_top_sim_0.1/sim-verilator/Votbn_top_sim \
    --load-elf=$testcase_elf -t --otbn-trace-file=otbn.trace | tee $RUN_LOG

  if [ $? -eq 124 ]; then
    fail "Simulation timeout"
  fi

  if [ $? -ne 0 ]; then
    fail "Simulator run failed"
  else
    echo "Verilator model matched ISS behaviour"
  fi
done
