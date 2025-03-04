[![Github Action (main)](https://github.com/cyber-dojo/runner/actions/workflows/main.yml/badge.svg)](https://github.com/cyber-dojo/runner/actions)

- A [docker-containerized](https://registry.hub.docker.com/r/cyberdojo/runner) micro-service for [https://cyber-dojo.org](http://cyber-dojo.org).
- An http service (rack based) for running `cyber-dojo.sh` inside a docker container for at most 20 seconds and returning `[stdout,stderr,status,timed_out,colour]`
- Demonstrates a [Kosli](https://www.kosli.com/) instrumented [GitHub CI workflow](https://app.kosli.com/cyber-dojo/flows/runner-ci/trails/) 
  deploying, with Continuous Compliance, to its [staging](https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/) AWS environment.
- Deployment to its [production](https://app.kosli.com/cyber-dojo/environments/aws-prod/snapshots/) AWS environment is via a separate [promotion workflow](https://github.com/cyber-dojo/aws-prod-co-promotion).
- Uses attestation patterns from https://www.kosli.com/blog/using-kosli-attest-in-github-action-workflows-some-tips/

# Development

There are two sets of tests:
- server: these run from inside the runner container
- client: these run from outside the runner container, making api calls only 

```bash
# Build the images
$ make {image_server|image_client}

# Run all tests
$ make {test_server|test_client}

# Run only specific tests
$ ./bin/run_tests.sh {-h|--help}
$ ./bin/run_tests.sh server C5a

# Check coverage metrics
$ make {coverage_server|coverage_client}

# Check image for snyk vulnerabilities
$ make snyk_container_scan

# Run demo
$ make demo
```

# API

* [GET alive](docs/api.md#get-alive)
* [GET ready](docs/api.md#get-ready)
* [GET sha](docs/api.md#get-sha)
* [GET base_image](docs/api.md#get-base-image)
* [POST run_cyber_dojo_sh(id,files,manifest)](docs/api.md#post-run_cyber_dojo_shidfilesmanifest)
* [POST pull_image(id,image_name)](docs/api.md#post-pull_imageidimage_name)

# Screenshots

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
