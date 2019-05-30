
[![CircleCI](https://circleci.com/gh/cyber-dojo/runner-stateless.svg?style=svg)](https://circleci.com/gh/cyber-dojo/runner-stateless)

<img src="https://raw.githubusercontent.com/cyber-dojo/nginx/master/images/home_page_logo.png"
alt="cyber-dojo yin/yang logo" width="50px" height="50px"/>

# cyberdojo/runner-stateless docker image

- A docker-containerized stateless micro-service for [cyber-dojo](http://cyber-dojo.org).
- Runs `cyber-dojo.sh` inside a docker container for at most max_seconds.

# API
  * [run_cyber_dojo_sh(image_name,id,files,max_seconds)](#run_cyber_dojo_shimage_nameidfilesmax_seconds)
  * [ready?](#ready)
  * [sha](#sha)

- - - -

# JSON in, JSON out  
  * All methods receive a JSON hash.
    * The hash contains any method arguments as key-value pairs.
  * All methods return a JSON hash.
    * If the method completes, a key equals the method's name.
    * If the method raises an exception, a key equals "exception".

- - - -

# run_cyber_dojo_sh(image_name,id,files,max_seconds)
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

# ready?
- parameters
  * none
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

# sha
- parameters
  * none
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

# run the tests
- Builds the runner-server image and an example runner-client image.
- Brings up a runner-server container and a runner-client container.
- Runs the runner-server's tests from inside a runner-server container.
- Runs the runner-client's tests from inside the runner-client container.
```
$ ./pipe_build_up_test.sh

Use: pipe_build_up_test.sh [client|server] [HEX-ID...]
Options:
   client  - only run the tests from inside the client
   server  - only run the tests from inside the server
   HEX-ID  - only run the tests matching this identifier

Building runner-stateless
Step 1/8 : FROM cyberdojo/docker-base
 ---> 9d1f06280f4d
Step 2/8 : LABEL maintainer=jon@jaggersoft.com
 ---> Using cache
 ---> 985da0ca2b94
Step 3/8 : WORKDIR /app
 ---> Using cache
 ---> 5ac8f3e2548b
Step 4/8 : COPY . .
 ---> Using cache
 ---> 9b1d20329a16
Step 5/8 : ARG SHA
 ---> Using cache
 ---> 6911053e42f4
Step 6/8 : ENV SHA=${SHA}
 ---> Using cache
 ---> 72abf5c7da8c
Step 7/8 : EXPOSE 4597
 ---> Using cache
 ---> 406b4216d24b
Step 8/8 : CMD [ "./up.sh" ]
 ---> Using cache
 ---> cf9a8ba4dc8c
Successfully built cf9a8ba4dc8c
Successfully tagged cyberdojo/runner-stateless:latest

Building runner-stateless-client
Step 1/5 : FROM  cyberdojo/docker-base
 ---> 9d1f06280f4d
Step 2/5 : LABEL maintainer=jon@jaggersoft.com
 ---> Using cache
 ---> 985da0ca2b94
Step 3/5 : COPY . /app
 ---> Using cache
 ---> 5e32e72ef70b
Step 4/5 : EXPOSE 4598
 ---> Using cache
 ---> 704a7fa8e551
Step 5/5 : CMD [ "./up.sh" ]
 ---> Using cache
 ---> 5bd4ca27b816
Successfully built 5bd4ca27b816
Successfully tagged cyberdojo/runner-stateless-client:latest

Recreating test-runner-stateless-server ... done
Recreating test-runner-stateless-client ... done
Waiting until test-runner-stateless-server is ready.OK
Checking test-runner-stateless-server started cleanly...OK

Run options: --seed 34605

# Running:

.....................................................................................

Finished in 73.529235s, 1.1560 runs/s, 22.2769 assertions/s.

85 runs, 1638 assertions, 0 failures, 0 errors, 0 skips
Coverage report generated for MiniTest to /tmp/coverage. 1510 / 1510 LOC (100.0%) covered.
Coverage report copied to runner-stateless/test_server/coverage/

                 failures |       0 ==     0 | true
                   errors |       0 ==     0 | true
                    skips |       0 ==     0 | true
        duration(test)[s] |   73.53 <=   100 | true
         coverage(src)[%] |   100.0 ==   100 | true
        coverage(test)[%] |   100.0 ==   100 | true
   lines(test)/lines(src) |    2.99 >=   2.8 | true
     hits(src)/hits(test) |   24.80 >=    23 | true

Run options: --seed 19227

# Running:

...............................

Finished in 13.761359s, 2.2527 runs/s, 10.3914 assertions/s.

31 runs, 143 assertions, 0 failures, 0 errors, 0 skips
Coverage report generated for MiniTest to /tmp/coverage. 338 / 338 LOC (100.0%) covered.
Coverage report copied to runner-stateless/test_client/coverage/

                 failures |       0 ==     0 | true
                   errors |       0 ==     0 | true
                    skips |       0 ==     0 | true
        duration(test)[s] |   13.76 <=    25 | true
         coverage(src)[%] |   100.0 ==   100 | true
        coverage(test)[%] |   100.0 ==   100 | true
   lines(test)/lines(src) |    5.26 >=     5 | true
     hits(src)/hits(test) |    1.69 >=   1.5 | true

------------------------------------------------------
All passed
Stopping test-runner-stateless-client ... done
Stopping test-runner-stateless-server ... done
Removing test-runner-stateless-client ... done
Removing test-runner-stateless-server ... done
Removing network runner-stateless_default
```

- - - -

# run the demo
- Runs inside the runner-client's container.
- Calls the runner-server's methods and displays their json results and how long they took.
- If the runner-client's IP address is 192.168.99.100 then put 192.168.99.100:4598 into your browser to see the output.
```
$ ./sh/run_demo.sh
```
![demo screenshot](test_client/src/demo_screenshot.png?raw=true "demo screenshot")

- - - -

* [Take me to cyber-dojo's home github repo](https://github.com/cyber-dojo/cyber-dojo).
* [Take me to the http://cyber-dojo.org site](http://cyber-dojo.org).

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
