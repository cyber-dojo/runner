#!/bin/bash

my_dir="$( cd "$( dirname "${0}" )" && pwd )"
${my_dir}/build.sh
${my_dir}/up.sh

. ${my_dir}/.env

echo "$(docker-machine ip default):${CYBER_DOJO_RUNNER_STATELESS_CLIENT_PORT}"
