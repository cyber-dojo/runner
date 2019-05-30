
[![CircleCI](https://circleci.com/gh/cyber-dojo/runner-stateless.svg?style=svg)](https://circleci.com/gh/cyber-dojo/runner-stateless)

<img src="https://raw.githubusercontent.com/cyber-dojo/nginx/master/images/home_page_logo.png"
alt="cyber-dojo yin/yang logo" width="50px" height="50px"/>

# cyberdojo/runner-stateless docker image

- A docker-containerized stateless micro-service for [cyber-dojo](http://cyber-dojo.org).
- Runs cyber-dojo.sh inside a docker container within a given amount of time.

API
  * [GET run_cyber_dojo_sh(image_name,id,files,max_seconds)](#post-run_cyber_dojo_shimage_nameidfilesmax_seconds)
  * [GET ready?()](#get-ready)
  * [GET sha()](#get-sha)

JSON in, JSON out  
  * All methods receive a JSON hash.
    * The hash contains any method arguments as key-value pairs.
  * All methods return a JSON hash.
    * If the method completes, a key equals the method's name.
    * If the method raises an exception, a key equals "exception".

- - - -

# GET run_cyber_dojo_sh(image_name,id,files,max_seconds)
- parameters
  * **image_name:String** must be created with [image_builder](https://github.com/cyber-dojo-languages/image_builder)
  * **id:String** for tracing, must be in [base58](https://github.com/cyber-dojo/runner-stateless/blob/master/src/base58.rb)
  * **files:Hash{String=>String}** must contain a file called `cyber-dojo.sh`
  * **max_seconds:Integer** must be between 1 and 20
  * eg
  ```
  { "image_name": "cyberdojofoundation/gcc_assert",
    "id": "15B9zD",
    "files": {
      "cyber-dojo.sh": "make",
      "fizz_buzz.c": "#include...",
      "fizz_buzz.h": "#ifndef FIZZ_BUZZ_INCLUDED...",
      ...
    },
    "max_seconds": 10
  }
  ```

- behaviour
  * creates a container from **image_name**
  * saves **files** into `/sandbox` inside the container
  * runs `/sandbox/cyber-dojo.sh` inside the container for at most **max_seconds**

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
    ```
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
    ```
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

- - - -

## GET ready?
- parameters
  * none
  * eg
  ```
  {}
  ```
- returns
  * **true** if the service is ready
  * **false** if the service is not ready
  * eg
  ```
  { "ready?": true }
  { "ready?": false }
  ```

- - - -

## GET sha
- parameters
  * none
  * eg
  ```
  {}
  ```
- returns
  * the git commit sha used to create the docker image
  * eg
  ```
  { "sha": "b28b3e13c0778fe409a50d23628f631f87920ce5" }
  ```

- - - -
- - - -

# run the tests
- Builds the runner-server image and an example runner-client image.
- Brings up a runner-server container and a runner-client container.
- Runs the runner-server's tests from inside a runner-server container.
- Runs the runner-client's tests from inside the runner-client container.
```
$ ./pipe_build_up_test.sh [client|server] [HEX-ID...]
```

# run the demo
- Runs inside the runner-client's container.
- Calls the runner-server's methods and displays their json results and how long they took.
- If the runner-client's IP address is 192.168.99.100 then put 192.168.99.100:4598 into your browser to see the output.
```
$ ./sh/run_demo.sh
```

# demo screenshot

![red amber green demo](docs/red_amber_green_demo.png?raw=true "red amber green demo")

- - - -

* [Take me to cyber-dojo's home github repo](https://github.com/cyber-dojo/cyber-dojo).
* [Take me to the http://cyber-dojo.org site](http://cyber-dojo.org).

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
