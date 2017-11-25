#!/bin/bash

if [ ! -f /.dockerenv ]; then
  echo 'FAILED: run.sh is being executed outside of docker-container.'
  echo 'Use pipe_build_up_test.sh'
  exit 1
fi

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"
readonly TEST_LOG=${CYBER_DOJO_COVERAGE_ROOT}/test.log

mkdir -p ${CYBER_DOJO_COVERAGE_ROOT}
cd ${MY_DIR}/src

readonly FILES=(*_test.rb)
readonly ARGS=(${*})

ruby -e "([ '../coverage.rb' ] + %w(${FILES[*]})).each{ |file| require './'+file }" \
  -- ${ARGS[@]} | tee ${TEST_LOG}

cd ${MY_DIR} \
  && ruby ./check_test_results.rb \
       ${TEST_LOG} \
       ${CYBER_DOJO_COVERAGE_ROOT}/index.html \
          > ${CYBER_DOJO_COVERAGE_ROOT}/done.txt
