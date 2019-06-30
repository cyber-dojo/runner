
[![CircleCI](https://circleci.com/gh/cyber-dojo/runner.svg?style=svg)](https://circleci.com/gh/cyber-dojo/runner)

- The source for the [cyberdojo/runner](https://hub.docker.com/r/cyberdojo/runner/tags) Docker image.
- A docker-containerized stateless micro-service for [https://cyber-dojo.org](http://cyber-dojo.org).
- Runs `cyber-dojo.sh` inside a docker container for at most max_seconds.

- - - -
# API
  * [GET run_cyber_dojo_sh(image_name,id,files,max_seconds)](#get-run_cyber_dojo_shimage_nameidfilesmax_seconds)
  * [GET ready?](#get-ready)
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

- - - -
# GET ready?
- parameters
  * none
  ```json
  {}
  ```
- returns
  * **true** if the service is ready
  * **false** if the service is not ready
  * eg
  ```json
  { "ready?": true }
  { "ready?": false }
  ```

- - - -
# GET sha
- parameters
  * none
  ```json
  {}
  ```
- returns
  * the git commit sha used to create the docker image
  * eg
  ```json
  { "sha": "b28b3e13c0778fe409a50d23628f631f87920ce5" }
  ```

- - - -
# build the image and run the tests
- Builds the runner-server image and an example runner-client image.
- Brings up a runner-server container and a runner-client container.
- Runs the runner-server's tests from inside a runner-server container.
- Runs the runner-client's tests from inside the runner-client container.

```text
$ ./pipe_build_up_test.sh

Use: pipe_build_up_test.sh [client|server] [HEX-ID...]
Options:
   client  - only run the tests from inside the client
   server  - only run the tests from inside the server
   HEX-ID  - only run the tests matching this identifier

Building runner-server
Step 1/8 : FROM cyberdojo/docker-base
---> 330a9d0f2304
Step 2/8 : LABEL maintainer=jon@jaggersoft.com
---> Using cache
---> 1f74f42bba70
Step 3/8 : WORKDIR /app
---> Using cache
---> 4325bfcd6524
Step 4/8 : COPY . .
---> Using cache
---> 21f49ad994dd
Step 5/8 : ARG SHA
---> Using cache
---> 727dbe6ee8fe
Step 6/8 : ENV SHA=${SHA}
---> Running in f08ce0e309cf
Removing intermediate container f08ce0e309cf
---> d3d4e288fcf0
Step 7/8 : EXPOSE 4597
---> Running in e40dd66d5e81
Removing intermediate container e40dd66d5e81
---> 2921e281fd8f
Step 8/8 : CMD [ "./up.sh" ]
---> Running in 7d9d1232abdc
Removing intermediate container 7d9d1232abdc
---> 52ebd68f0b04
Successfully built 52ebd68f0b04
Successfully tagged cyberdojo/runner:latest

Building runner-client
Step 1/5 : FROM  cyberdojo/docker-base
---> 330a9d0f2304
Step 2/5 : LABEL maintainer=jon@jaggersoft.com
---> Using cache
---> 1f74f42bba70
Step 3/5 : COPY . /app
---> Using cache
---> 9a37f9be7fe1
Step 4/5 : EXPOSE 4598
---> Using cache
---> e72bdcaca0da
Step 5/5 : CMD [ "./up.sh" ]
---> Using cache
---> 2f271e2cc034
Successfully built 2f271e2cc034
Successfully tagged cyberdojo/runner-client:latest

Creating network "runner_default" with the default driver
Creating test-runner-server ... done
Creating test-runner-client ... done
Waiting until test-runner-server is ready.....OK
Checking test-runner-server started cleanly...OK

Run options: --seed 48524

# Running:

....................................................................................

Finished in 81.214118s, 1.0343 runs/s, 20.0088 assertions/s.

84 runs, 1625 assertions, 0 failures, 0 errors, 0 skips
Coverage report generated for MiniTest to /tmp/coverage. 1498 / 1498 LOC (100.0%) covered.
Coverage report copied to runner/test_server/coverage/

                   tests |      84 !=     0 | true
                failures |       0 ==     0 | true
                  errors |       0 ==     0 | true
                warnings |       0 ==     0 | true
                   skips |       0 ==     0 | true
       duration(test)[s] |   81.21 <=    90 | true
        coverage(src)[%] |   100.0 ==   100 | true
       coverage(test)[%] |   100.0 ==   100 | true
  lines(test)/lines(src) |    3.08 >=   2.8 | true
    hits(src)/hits(test) |   25.59 >=    23 | true

Run options: --seed 21449

# Running:

...............................

Finished in 14.202317s, 2.1827 runs/s, 10.0688 assertions/s.

31 runs, 143 assertions, 0 failures, 0 errors, 0 skips
Coverage report generated for MiniTest to /tmp/coverage. 345 / 345 LOC (100.0%) covered.
Coverage report copied to runner/test_client/coverage/

                   tests |      31 !=     0 | true
                failures |       0 ==     0 | true
                  errors |       0 ==     0 | true
                warnings |       0 ==     0 | true
                   skips |       0 ==     0 | true
       duration(test)[s] |    14.2 <=    25 | true
        coverage(src)[%] |   100.0 ==   100 | true
       coverage(test)[%] |   100.0 ==   100 | true
  lines(test)/lines(src) |    5.39 >=     5 | true
    hits(src)/hits(test) |    1.66 >=   1.5 | true

------------------------------------------------------
All passed
Stopping test-runner-client ... done
Stopping test-runner-server ... done
Removing test-runner-client ... done
Removing test-runner-server ... done
Removing network runner_default
```

- - - -
# build the demo and run it
- Runs inside the runner-client's container.
- Calls the runner-server's methods and displays their json results and how long they took.
- If the runner-client's IP address is 192.168.99.100 then put 192.168.99.100:4598 into your browser to see the output.

```bash
$ ./sh/run_demo.sh
```
![demo screenshot](test_client/src/demo_screenshot.png?raw=true "demo screenshot")

- - - -
![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
