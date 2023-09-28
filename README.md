[![Github Action (main)](https://github.com/cyber-dojo/runner/actions/workflows/main.yml/badge.svg)](https://github.com/cyber-dojo/runner/actions)

- A [docker-containerized](https://registry.hub.docker.com/r/cyberdojo/runner) micro-service for [https://cyber-dojo.org](http://cyber-dojo.org).
- An http service (rack based) for running `cyber-dojo.sh` inside a docker container for at most 20 seconds and returning `[stdout,stderr,status,timed_out,colour]`
- A [Kosli](https://www.kosli.com/) showcase for a [CI flow](https://app.kosli.com/cyber-dojo/flows/exercises-start-points/artifacts/) and an [aws production environment](https://app.kosli.com/cyber-dojo/environments/aws-prod/snapshots/)


***
API

* [POST run_cyber_dojo_sh(id,files,manifest)](docs/api.md#post-run_cyber_dojo_shidfilesmanifest)
* [POST pull_image(id,image_name)](docs/api.md#post-pull_imageidimage_name)

* [GET alive](docs/api.md#get-alive)  
* [GET ready](docs/api.md#get-ready)
* [GET sha](docs/api.md#get-sha)

***

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
