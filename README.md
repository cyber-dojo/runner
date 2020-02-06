[![CircleCI](https://circleci.com/gh/cyber-dojo/runner.svg?style=svg)](https://circleci.com/gh/cyber-dojo/runner)
[![License](https://img.shields.io/badge/license-BSD--2-brightgreen)]((https://github.com/cyber-dojo/runner/blob/master/LICENSE.md))
![code size](https://img.shields.io/github/languages/code-size/cyber-dojo/runner)
![repo size](https://img.shields.io/github/repo-size/cyber-dojo/runner)
[![Hits-of-Code](https://hitsofcode.com/github/cyber-dojo/runner)](https://hitsofcode.com/view/github/cyber-dojo/runner)

- The source for the [cyberdojo/runner](https://hub.docker.com/r/cyberdojo/runner/tags) Docker image.
- A docker-containerized micro-service for [https://cyber-dojo.org](https://cyber-dojo.org).
- An http service (rack based) for running `cyber-dojo.sh` inside a docker container for at most `max_seconds` and returning `[stdout,stderr,status,timed_out,colour]`
  * [GET run_cyber_dojo_sh(image_name,id,files,max_seconds)](docs/api.md#get-run_cyber_dojo_shimage_nameidfilesmax_seconds)
  * [GET ready?](docs/api.md#get-ready)
  * [GET alive?](docs/api.md#get-alive)  
  * [GET sha](docs/api.md#get-sha)

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
