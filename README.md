[![CircleCI](https://circleci.com/gh/cyber-dojo/runner.svg?style=svg)](https://circleci.com/gh/cyber-dojo/runner)

- The source for the [cyberdojo/runner](https://hub.docker.com/r/cyberdojo/runner/tags) Docker image.
- A docker-containerized micro-service for [https://cyber-dojo.org](https://cyber-dojo.org).
- An http service (rack based) for running `cyber-dojo.sh` inside a docker container for at most max_seconds.

- - - -
# API
  * [GET run_cyber_dojo_sh(image_name,id,files,max_seconds)](#get-run_cyber_dojo_shimage_nameidfilesmax_seconds)
  * [GET ready?](#get-ready)
  * [GET alive?](#get-alive)    
  * [GET sha](#get-sha)

- - - -
# JSON in, JSON out  
  * All methods receive a JSON hash.
    * The hash contains any method arguments as key-value pairs.
  * All methods return a JSON hash.
    * If the method completes, a key equals the method's name.
    * If the method raises an exception, a key equals "exception".

- - - -
# GET run_cyber_dojo_sh(image_name,id,files,max_seconds)
Runs `cyber-dojo.sh` inside a docker container for at most max_seconds.
- returns  
  * **stdout:String** of running `/sandbox/cyber-dojo.sh` truncated to 50K
  * **stderr:String** of running `/sandbox/cyber-dojo.sh` truncated to 50K
  * **status:Integer** of running `/sandbox/cyber-dojo.sh` 0 to 255
  * **timed_out:Boolean**
    * **false** if execution completed in **max_seconds**
    * **true** if execution did not complete in **max_seconds**
  * **created:Hash** text-files created under `/sandbox` each truncated to 50K
  * **deleted:Array[String]** names of text-files deleted from under `/sandbox`
  * **changed:Hash** text-files changed under `/sandbox` each truncated to 50K
  * eg
    ```json
    { "run_cyber_dojo_sh": {
        "stdout": {
          "content": "makefile:17: recipe for target 'test' failed\n",
          "truncated": false
        },
        "stderr": {
          "content": "invalid suffix sss on integer constant",
          "truncated": false
        },
        "status": 2,
        "timed_out": false,
        "created": {
          "coverage.html": {
            "content": "...",
            "truncated": false
          }
        },
        "deleted": [],
        "changed": {
          "todo.txt": {
            "content": "...",
            "truncated": false
          }
        }
      }
    }
    ```
  * eg
    ```json
    { "run_cyber_dojo_sh": {
        "stdout": {
          "content": "",
          "truncated": false
        },
        "stderr": {
          "content": "",
          "truncated": false
        },
        "status": 137,
        "timed_out": true,
        "created": {},
        "deleted": [ "filename.txt" ],
        "changed": {}
      }
    }
    ```
- parameters
  * **image_name:String** must be created with [image_builder](https://github.com/cyber-dojo-languages/image_builder)
  * **id:String** for tracing, must be in [base58](https://github.com/cyber-dojo/runner/blob/master/src/base58.rb)
  * **files:Hash{String=>String}** must contain a file called `cyber-dojo.sh`
  * **max_seconds:Integer** must be between 1 and 20
  * eg
  ```json
  { "image_name": "cyberdojofoundation/gcc_assert",
    "id": "15B9zD",
    "files": {
      "cyber-dojo.sh": "make",
      "fizz_buzz.c": "#include...",
      "fizz_buzz.h": "#ifndef FIZZ_BUZZ_INCLUDED...",
      "fizz_buzz.tests.c": "#include \"fizz_buzz.h\"...",
      "makefile": "CFLAGS += -I. ........"
    },
    "max_seconds": 10
  }
  ```
- behaviour
  * creates a container from **image_name**
  * saves **files** into `/sandbox` inside the container
  * runs `/sandbox/cyber-dojo.sh` inside the container for at most **max_seconds**


- - - -
# GET ready?
Useful as a readiness probe.
- returns
  * **true** if the service is ready
  ```json
  { "ready?": true }
  ```
  * **false** if the service is not ready
  ```json
  { "ready?": false }
  ```
- parameters
  * none
  ```json
  {}
  ```

- - - -
# GET alive?
Useful as a liveness probe.
- returns
  * **true**
  ```json
  { "alive?": true }
  ```
- parameters
  * none
  ```json
  {}
  ```

- - - -
## GET sha
The git commit sha used to create the Docker image.
- returns
  * The 40 character sha string.
  * eg
  ```json
  { "sha": "b28b3e13c0778fe409a50d23628f631f87920ce5" }
  ```
- parameters
  * none
  ```json
  {}
  ```

- - - -
![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
