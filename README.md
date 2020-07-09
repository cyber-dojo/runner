[![CircleCI](https://circleci.com/gh/cyber-dojo/runner.svg?style=svg)](https://circleci.com/gh/cyber-dojo/runner)

- The source for the [cyberdojo/runner](https://hub.docker.com/r/cyberdojo/runner/tags) Docker image.
- A docker-containerized micro-service for [https://cyber-dojo.org](https://cyber-dojo.org).
- An http service (rack based) for running `cyber-dojo.sh` inside a docker container for at most 20 seconds and returning `[stdout,stderr,status,timed_out,colour]`

***
API

* [GET alive?](docs/api.md#get-alive)  
* [GET ready?](docs/api.md#get-ready)
* [GET sha](docs/api.md#get-sha)
* [POST pull_image(id,image_name)](docs/api.md#post-pull_imageidimage_name)
* [POST run_cyber_dojo_sh(id,files,manifest)](docs/api.md#post-run_cyber_dojo_shidfilesmanifest)

***

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
