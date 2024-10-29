#!/bin/bash -Eeu

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPORTS_ROOT="${1}"  # eg /tmp/reports
readonly TEST_LOG="${2}"    # eg test.run.log
readonly TYPE="${3}"        # eg client|server
shift; shift; shift

readonly TEST_FILES=(${MY_DIR}/../${TYPE}/*_test.rb ${MY_DIR}/../dual/*_test.rb)
readonly TEST_ARGS=(${@})

readonly SCRIPT="
require '${MY_DIR}/coverage.rb'
%w(${TEST_FILES[*]}).shuffle.each{ |file|
  require file
}"

export RUBYOPT='-W2'
mkdir -p ${REPORTS_ROOT}/coverage
mkdir -p ${REPORTS_ROOT}/junit

set +e
ruby -e "${SCRIPT}" -- ${TEST_ARGS[@]} 2>&1 | tee ${REPORTS_ROOT}/${TEST_LOG}
STATUS=${PIPESTATUS[0]}
set -e

exit "${STATUS}"
