#!/bin/bash

if [ ! -f /.dockerenv ]; then
  echo 'FAILED: run.sh is being executed outside of docker-container.'
  echo 'Use pipe_build_up_test.sh'
  exit 1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# client

cov_dir=${CYBER_DOJO_COVERAGE_ROOT}
test_log=${cov_dir}/test.log

my_dir="$( cd "$( dirname "${0}" )" && pwd )"
cd ${my_dir}/src
files=(*_test.rb)
args=(${*})

ruby -e "([ '../coverage.rb' ] + %w(${files[*]}).shuffle).each{ |file| require './'+file }" \
  -- ${args[@]} | tee ${test_log}

cd ${my_dir} \
  && ruby ./check_test_results.rb ${test_log} ${cov_dir}/index.html > ${cov_dir}/done.txt
