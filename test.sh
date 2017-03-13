#!/bin/bash

my_dir="$( cd "$( dirname "${0}" )" && pwd )"
my_name="${my_dir##*/}"

server_cid=`docker ps --all --quiet --filter "name=${my_name}_server"`
server_status=0

client_cid=`docker ps --all --quiet --filter "name=${my_name}_client"`
client_status=0

# - - - - - - - - - - - - - - - - - - - - - - - - - -

. ${my_dir}/.env

run_server_tests()
{
  docker exec ${server_cid} sh -c "cd test && ./run.sh ${*}"
  server_status=$?
  rm -rf ${my_dir}/server/coverage/
  docker cp ${server_cid}:${CYBER_DOJO_COVERAGE_ROOT}/. ${my_dir}/server/coverage/
  echo "Coverage report copied to ${my_dir}/server/coverage"
  cat ${my_dir}/server/coverage/done.txt
}

run_client_tests()
{
  docker exec ${client_cid} sh -c "cd test && ./run.sh ${*}"
  client_status=$?
  rm -rf ${my_dir}/client/coverage
  docker cp ${client_cid}:${CYBER_DOJO_COVERAGE_ROOT}/. ${my_dir}/client/coverage/
  echo "Coverage report copied to ${my_dir}/client/coverage"
  cat ${my_dir}/client/coverage/done.txt
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -

run_server_tests ${*}
#run_client_tests ${*}

if [[ ( ${server_status} == 0 && ${client_status} == 0 ) ]];  then
  echo "------------------------------------------------------"
  echo "All passed"
  exit 0
else
  echo
  echo "server: cid = ${server_cid}, status = ${server_status}"
  if [ "${server_cid}" != "0" ]; then
    docker logs ${my_name}_server
  fi
  echo "client: cid = ${client_cid}, status = ${client_status}"
  if [ "${client_cid}" != "0" ]; then
    docker logs ${my_name}_client
  fi
  echo
  exit 1
fi
