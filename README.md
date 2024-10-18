[![Github Action (main)](https://github.com/cyber-dojo/runner/actions/workflows/main.yml/badge.svg)](https://github.com/cyber-dojo/runner/actions)

- A [docker-containerized](https://registry.hub.docker.com/r/cyberdojo/runner) micro-service for [https://cyber-dojo.org](http://cyber-dojo.org).
- An http service (rack based) for running `cyber-dojo.sh` inside a docker container for at most 20 seconds and returning `[stdout,stderr,status,timed_out,colour]`
- A [Kosli CI flow](https://app.kosli.com/cyber-dojo/flows/runner-ci/trails/) 
  deploying, with Continuous Compliance, to [staging](https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/) and [production](https://app.kosli.com/cyber-dojo/environments/aws-prod/snapshots/) AWS environments.
- Demonstrates a [Kosli](https://www.kosli.com/) instrumented [GitHub CI workflow](https://app.kosli.com/cyber-dojo/flows/runner-ci/trails/) 
  deploying, with Continuous Compliance, to [staging](https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/) and [production](https://app.kosli.com/cyber-dojo/environments/aws-prod/snapshots/) AWS environments.
- Uses patterns from https://www.kosli.com/blog/using-kosli-attest-in-github-action-workflows-some-tips/

***
API

* [POST run_cyber_dojo_sh(id,files,manifest)](docs/api.md#post-run_cyber_dojo_shidfilesmanifest)
* [POST pull_image(id,image_name)](docs/api.md#post-pull_imageidimage_name)

* [GET alive](docs/api.md#get-alive)  
* [GET ready](docs/api.md#get-ready)
* [GET sha](docs/api.md#get-sha)

***

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
