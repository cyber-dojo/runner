
[![CircleCI](https://circleci.com/gh/cyber-dojo/runner-stateless.svg?style=svg)](https://circleci.com/gh/cyber-dojo/runner-stateless)

<img src="https://raw.githubusercontent.com/cyber-dojo/nginx/master/images/home_page_logo.png"
alt="cyber-dojo yin/yang logo" width="50px" height="50px"/>

# cyberdojo/runner-stateless docker image

- A docker-containerized stateless micro-service for [cyber-dojo](http://cyber-dojo.org).
- Runs cyber-dojo.sh inside a docker container within a given amount of time.

API:
  * [POST run_cyber_dojo_sh(image_name,id,files,max_seconds)](#post-run_cyber_dojo_shimage_nameidfilesmax_seconds)
  * [GET ready?()](#get-ready)
  * [GET sha()](#get-sha)
  * All methods receive a json hash.
    * The hash contains any method arguments as key-value pairs.
  * All methods return a json hash.
    * If the method completes, a key equals the method's name.
    * If the method raises an exception, a key equals "exception".

- - - -

# POST run_cyber_dojo_sh(image_name,id,files,max_seconds)
- Creates a container from **image_name**,
saves **files** into /sandbox inside it,
runs /sandbox/cyber-dojo.sh
for at most **max_seconds**.
**image_name** must be created with
[image_builder](https://github.com/cyber-dojo-languages/image_builder)
  * returns [**stdout**, **stderr**, **status**, **colour**] as the results of
executing cyber-dojo.sh
  * returns [**created**, **deleted**, **changed**] which are text files
in /sandbox altered by executing /sandbox/cyber-dojo.sh
  * if the execution completed in max_seconds, **colour** will be "red", "amber", or "green".
  * if the execution did not complete in max_seconds, **colour** will be "timed_out".
eg
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
         "colour": "amber",
        "created": { ... },
        "deleted": {},
        "changed": { ... }
      }
    }
```
eg
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
          "colour: "timed_out",
        "created": {},
        "deleted": {},
        "changed": {}
      }
    }
```

The [traffic-light colour](http://blog.cyber-dojo.org/2014/10/cyber-dojo-traffic-lights.html)
is determined by passing the **stdout**, **stderr**, **status** strings to a Ruby lambda, read from
**image_name**, at /usr/local/bin/red_amber_green.rb.

eg
```
$ docker run --rm cyberdojofoundation/gcc_assert bash -c 'cat /usr/local/bin/red_amber_green.rb'
lambda { |stdout, stderr, status|
  output = stdout + stderr
  return :red   if /(.*)Assertion(.*)failed./.match(output)
  return :green if /(All|\d+) tests passed/.match(output)
  return :amber
}
```
- If this file does not exist in **image_name**, the **colour** is "amber".
- If the contents of this file raises an exception when eval'd or called, the **colour** is "amber".
- If the lambda returns anything other than :red, :amber, or :green, the **colour** is "amber".

- parameters, eg
```
  {        "image_name": "cyberdojofoundation/gcc_assert",
                   "id": "15B9zD",
          "max_seconds": 10,
                "files": { "cyber-dojo.sh": "make",
                             "fizz_buzz.c": "#include...",
                             "fizz_buzz.h": "#ifndef FIZZ_BUZZ_INCLUDED...",
                           ...
                         }
  }
```

- - - -

## GET ready?
- parameters, none
```
  {}
```
- returns true if the service is ready, otherwise false, eg
```
  { "ready?": true }
  { "ready?": false }
```

- - - -

## GET sha
- parameters, none
```
  {}
```
- returns the git commit sha used to create the docker image, eg
```
  { "sha": "b28b3e13c0778fe409a50d23628f631f87920ce5" }
```

- - - -
- - - -

# build the docker images
Builds the runner-server image and an example runner-client image.
```
$ ./sh/build_docker_images.sh
```

# bring up the docker containers
Brings up a runner-server container and a runner-client container.

```
$ ./sh/docker_containers_up.sh
```

# run the tests
Runs the runner-server's tests from inside a runner-server container
and then the runner-client's tests from inside the runner-client container.
```
$ ./sh/run_tests_in_containers.sh
```

# run the demo
```
$ ./sh/run_demo.sh
```
Runs inside the runner-client's container.
Calls the runner-server's methods
and displays their json results and how long they took.
If the runner-client's IP address is 192.168.99.100 then put
192.168.99.100:4598 into your browser to see the output.
- red: tests ran but failed
- amber: tests did not run (eg syntax error)
- green: tests ran and passed
- grey: tests did not complete (in 3 seconds)

# demo screenshot

![red amber green demo](docs/red_amber_green_demo.png?raw=true "red amber green demo")

- - - -

* [Take me to cyber-dojo's home github repo](https://github.com/cyber-dojo/cyber-dojo).
* [Take me to the http://cyber-dojo.org site](http://cyber-dojo.org).

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
