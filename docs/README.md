
[![Build Status](https://travis-ci.org/cyber-dojo/runner-stateless.svg?branch=master)](https://travis-ci.org/cyber-dojo/runner-stateless)

<img src="https://raw.githubusercontent.com/cyber-dojo/nginx/master/images/home_page_logo.png"
alt="cyber-dojo yin/yang logo" width="50px" height="50px"/>

# cyberdojo/runner-stateless docker image

- A docker-containerized stateless micro-service for [cyber-dojo](http://cyber-dojo.org).
- Runs an avatar's tests.

API:
  * All methods receive their named arguments in a json hash.
    * image_name must be an docker image created with [image_builder](https://github.com/cyber-dojo-languages/image_builder)
  * All methods return a json hash.
    * If the method completes, a key equals the method's name.
    * If the method raises an exception, a key equals "exception".

- - - -

## GET sha
Returns the git commit sha used to create the docker image.
- parameters, none
```
  {}
```
- returns the sha, eg
```
  { "sha": "b28b3e13c0778fe409a50d23628f631f87920ce5" }
```

- - - -

# POST kata_new
A no-op, but arguments must be well-formed.
Provided for API compatibility with other runners.
- parameters, eg
```
  { "image_name": "cyberdojofoundation/gcc_assert",
       "kata_id": "15B9AD6C42"
  }
```

# POST kata_old
A no-op, but arguments must be well-formed.
Provided for API compatibility with other runners.
- parameters, eg
```
  { "image_name": "cyberdojofoundation/gcc_assert",
       "kata_id": "15B9AD6C42"
  }
```

- - - -

# POST avatar_new
A no-op, but arguments must be well-formed.
Provided for API compatibility with other runners.
- parameters, eg
```
  {     "image_name": "cyberdojofoundation/gcc_assert",
           "kata_id": "15B9AD6C42",
       "avatar_name": "salmon",
    "starting_files": { "hiker.h" => "#ifndef HIKER_INCLUDED...",
                        "hiker.c" => "#include...",
                        ...
                      }
  }
```

# POST avatar_old
A no-op, but arguments must be well-formed.
Provided for API compatibility with other runners.
- parameters, eg
```
  {  "image_name": "cyberdojofoundation/gcc_assert",
        "kata_id": "15B9AD6C42",
    "avatar_name": "salmon"
  }
```

- - - -

# POST run_cyber_dojo_sh
Saves the unchanged files, the changed_files, and the new files, and runs
cyber-dojo.sh as the avatar with the given avatar_name.
- parameters, eg
```
  {        "image_name": "cyberdojofoundation/gcc_assert",
              "kata_id": "15B9AD6C42",
          "avatar_name": "salmon",
            "new_files": { ... },
        "deleted_files": { ... },
      "unchanged_files": { "cyber-dojo.sh" => "make" },
        "changed_files": { "fizz_buzz.c" => "#include...",
                           "fizz_buzz.h" => "#ifndef FIZZ_BUZZ_INCLUDED...",
                           ...
                         },
          "max_seconds": 10
  }
```
- returns [stdout, stderr, status, colour] as the results of
executing cyber-dojo.sh
- returns [new_files, deleted_files, changed_files] which are text files
altered by executing cyber-dojo.sh
- if the execution completed in max_seconds, colour will be "red", "amber", or "green".
- if the execution did not complete in max_seconds, colour will be "timed_out".

eg
```
    { "run_cyber_dojo_sh": {
        "stdout": "makefile:17: recipe for target 'test' failed\n",
        "stderr": "invalid suffix sss on integer constant",
        "status": 2,
        "colour": "amber",
        "new_files":{ ... },
        "deleted_files":{},
        "changed_files":{ ... }
      }
    }
```
eg
```
    { "run_cyber_dojo_sh": {
        "stdout": "...",
        "stderr": "...",
        "status": 137,
        "colour:"timed_out",
        "new_files":{},
        "deleted_files":{},
        "changed_files":{}
      }
    }
```

The [traffic-light colour](http://blog.cyber-dojo.org/2014/10/cyber-dojo-traffic-lights.html)
is determined by passing stdout, stderr, and status to a Ruby lambda, read from the
named image, at /usr/local/bin/red_amber_green.rb.

eg
```
lambda { |stdout, stderr, status|
  output = stdout + stderr
  return :red   if /(.*)Assertion(.*)failed./.match(output)
  return :green if /(All|\d+) tests passed/.match(output)
  return :amber
}
```
- If this file does not exist in the named image, the colour is "amber".
- If the contents of this file raises an exception when eval'd or called, the colour is "amber".
- If the lambda returns anything other than :red, :amber, or :green, the colour is "amber".

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
Calls the runner-server's micro-service methods
and displays their json results and how long they took.
If the runner-client's IP address is 192.168.99.100 then put
192.168.99.100:4598 into your browser to see the output.
- grey: tests did not complete (in 3 seconds)
- red: tests ran but failed
- amber: tests did not run (syntax error)
- green: tests ran and passed

# demo screenshot

![red amber green demo](red_amber_green_demo.png?raw=true "red amber green demo")

- - - -

* [Take me to cyber-dojo's home github repo](https://github.com/cyber-dojo/cyber-dojo).
* [Take me to the http://cyber-dojo.org site](http://cyber-dojo.org).

![cyber-dojo.org home page](https://github.com/cyber-dojo/cyber-dojo/blob/master/shared/home_page_snapshot.png)
