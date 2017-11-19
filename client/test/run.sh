#!/bin/bash

if [ ! -f /.dockerenv ]; then
  echo 'FAILED: run.sh is being executed outside of docker-container.'
  echo 'Use pipe_build_up_test.sh'
  exit 1
fi

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"
readonly COV_DIR=${CYBER_DOJO_COVERAGE_ROOT}
readonly TEST_LOG=${COV_DIR}/test.log

cd ${MY_DIR}/src

readonly FILES=(*_test.rb)
readonly ARGS=(${*})

ruby -e "([ '../coverage.rb' ] + %w(${FILES[*]}).shuffle).each{ |file| require './'+file }" \
  -- ${ARGS[@]} | tee ${TEST_LOG}

cd ${MY_DIR} \
  && ruby ./check_test_results.rb \
       ${TEST_LOG} \
       ${COV_DIR}/index.html \
         > ${COV_DIR}/done.txt
