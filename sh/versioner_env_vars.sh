#!/bin/bash -Ee

versioner_env_vars()
{
  docker run --rm cyberdojo/versioner:latest
  echo 'CYBER_DOJO_RUNNER_DEMO_PORT=4598'
}
