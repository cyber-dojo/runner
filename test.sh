#!/bin/bash

run_server_tests()
{
  docker exec ${SERVER_CID} sh -c "cd test && ./run.sh ${*}"
  server_status=$?
  rm -rf ${MY_DIR}/server/coverage/
  docker cp ${SERVER_CID}:${CYBER_DOJO_COVERAGE_ROOT}/. ${MY_DIR}/server/coverage/
  echo "Coverage report copied to ${MY_DIR}/server/coverage"
  cat ${MY_DIR}/server/coverage/done.txt
}

run_client_tests()
{
  docker exec ${CLIENT_CID} sh -c "cd test && ./run.sh ${*}"
  client_status=$?
  rm -rf ${MY_DIR}/client/coverage
  docker cp ${CLIENT_CID}:${CYBER_DOJO_COVERAGE_ROOT}/. ${MY_DIR}/client/coverage/
  echo "Coverage report copied to ${MY_DIR}/client/coverage"
  cat ${MY_DIR}/client/coverage/done.txt
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"
readonly MY_NAME="${MY_DIR##*/}"

readonly SERVER_CID=`docker ps --all --quiet --filter "name=${MY_NAME}_server"`
readonly CLIENT_CID=`docker ps --all --quiet --filter "name=${MY_NAME}_client"`

server_status=0
client_status=0
. ${MY_DIR}/.env
run_server_tests ${*}
run_client_tests ${*}

if [[ ( ${server_status} == 0 && ${client_status} == 0 ) ]];  then
  echo "------------------------------------------------------"
  echo "All passed"
  exit 0
else
  echo
  echo "server: cid = ${SERVER_CID}, status = ${server_status}"
  if [ "${server_status}" != "0" ]; then
    docker logs ${MY_NAME}_server
  fi
  echo "client: cid = ${CLIENT_CID}, status = ${client_status}"
  if [ "${client_status}" != "0" ]; then
    docker logs ${MY_NAME}_client
  fi
  echo
  exit 1
fi
