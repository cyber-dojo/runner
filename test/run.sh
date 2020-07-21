#!/bin/bash -Eeu

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export COVERAGE_ROOT="${1}" # /tmp/coverage
readonly TEST_LOG="${2}"    # test.log
readonly TYPE="${3}"        # client|server
shift; shift; shift

readonly TEST_FILES=(${MY_DIR}/${CONTEXT}_*_test.rb)
readonly TEST_ARGS=(${@})

readonly SCRIPT="
require '${MY_DIR}/coverage.rb'
%w(${TEST_FILES[*]}).shuffle.each{ |file|
  require file
}"

export RUBYOPT='-W2'
mkdir -p ${COVERAGE_ROOT}

set +e
ruby -e "${SCRIPT}" -- ${TEST_ARGS[@]} 2>&1 | tee ${COVERAGE_ROOT}/${TEST_LOG}
set -e
