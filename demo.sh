#!/bin/bash

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"
${MY_DIR}/build.sh
${MY_DIR}/up.sh

. ${MY_DIR}/.env
