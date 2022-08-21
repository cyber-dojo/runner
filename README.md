[![Github Action (main)](https://github.com/cyber-dojo/runner/actions/workflows/main.yml/badge.svg)](https://github.com/cyber-dojo/runner/actions)

- The source for the [cyberdojo/runner](https://hub.docker.com/r/cyberdojo/runner/tags) Docker image.
- A docker-containerized micro-service for [https://cyber-dojo.org](https://cyber-dojo.org).
- An http service (rack based) for running `cyber-dojo.sh` inside a docker container for at most 20 seconds and returning `[stdout,stderr,status,timed_out,colour]`

***
API

* [POST run_cyber_dojo_sh(id,files,manifest)](docs/api.md#post-run_cyber_dojo_shidfilesmanifest)
* [POST pull_image(id,image_name)](docs/api.md#post-pull_imageidimage_name)

* [GET alive](docs/api.md#get-alive)  
* [GET ready](docs/api.md#get-ready)
* [GET sha](docs/api.md#get-sha)

***

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
