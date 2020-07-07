#!/bin/bash -Ee

versioner_env_vars()
{
  docker run --rm cyberdojo/versioner:latest
  echo CYBER_DOJO_RUNNER_DEMO_PORT=9999
  echo CYBER_DOJO_RUNNER_CLIENT_USER=nobody
  echo CYBER_DOJO_RUNNER_SERVER_USER=root
}
