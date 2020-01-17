# API

- - - -
# GET run_cyber_dojo_sh(image_name,id,files,max_seconds)
Runs `cyber-dojo.sh` inside a docker container for at most max_seconds.
- [JSON-in](#json-in) parameters
  * **image_name:String** created with [image_builder](https://github.com/cyber-dojo-languages/image_builder)
  * **id:String** for tracing
  * **files:Hash{String=>String}** assumed to contain a file called `"cyber-dojo.sh"`
  * **max_seconds:Integer** between `1` and `20`
  * eg
  ```json
  { "image_name": "cyberdojofoundation/python_pytest",
    "id": "34de2W",
    "files": {
      "cyber-dojo.sh": "coverage3 run --source='.' -m pytest *test*.py\n...",      
      "hiker.py": "#class Hiker:...",
      "test_hiker.py": "import hiker\n...",
      "readme.txt": "You task is to..."
    },
    "max_seconds": 10
  }
  ```
- returns the [JSON-out](#json-out) results, keyed on `"run_cyber_dojo_sh"`
  * **stdout:String** of running `/sandbox/cyber-dojo.sh` truncated to 50K
  * **stderr:String** of running `/sandbox/cyber-dojo.sh` truncated to 50K
  * **status:Integer** of running `/sandbox/cyber-dojo.sh` (0 to 255)
  * **timed_out:Boolean**
    * **false** if execution completed in **max_seconds**
    * **true** if execution did not complete in **max_seconds**
  * **created:Hash** text-files created under `/sandbox`, each truncated to 50K
  * **deleted:Array[String]** names of text-files deleted from `/sandbox`
  * **changed:Hash** text-files changed under `/sandbox`, each truncated to 50K
  * eg
    ```json
    { "run_cyber_dojo_sh": {
        "stdout": {
          "content": "...\nE       assert 54 == 42\n...",
          "truncated": false
        },
        "stderr": {
          "content": "",
          "truncated": false
        },
        "status": 2,
        "timed_out": false,
        "created": {
          "report/coverage.txt": {
            "content": "...\nhiker.py            3      0   100%\n...",
            "truncated": false
          }
        },
        "deleted": [],
        "changed": {}
      }
    }
    ```
- if `timed_out` is `false`, also returns the
[traffic-light colour](http://blog.cyber-dojo.org/2014/10/cyber-dojo-traffic-lights.html),
 keyed on `"colour"`.
  * eg
  ```json
  { "run_cyber_dojo": {
      ...,
      "stdout": { "content": "...", ... },
      "stderr": { "content": "...", ... },
      "status": 2,
      "timed_out": "false",
      ...
    },
    "colour": "green"
  }
  ```
  - notes
    * `"colour"` equals `"red"`, `"amber"`, `"green"`, or `"faulty"`
      as determined by passing `stdout['content']`, `stderr['content']`, `status`      
      to the Ruby lambda, read from **image_name**, at `/usr/local/bin/red_amber_green.rb`
    * if `/usr/local/bin/red_amber_green.rb` does not exist in **image_name**, then `"colour"` is `"faulty"`.
    * if eval'ing the lambda raises an exception, then `"colour"` is `"faulty"`.
    * if calling the lambda raises an exception, then `"colour"` is `"faulty"`.
    * if calling the lambda returns anything other than `:red`, `:amber`, or `:green`,
      then `"colour"` is `"faulty"`.
- if `"colour"` is `"faulty"`, also returns information keyed on `"diagnostic"`.
  * eg    
  ```json
  { "run_cyber_dojo_sh": { ... },
    "colour": "faulty",
    "diagnostic": {
      "image_name": "cyberdojofoundation/python_pytest",
      "id": "34de2W",
      "info": "eval(rag_lambda) raised an exception",
      "name:": "SyntaxError",
      "message": [
        "/app/src/empty.rb:25: syntax error, unexpected tIDENTIFIER, expecting end",
        "     return :amber sdf if",
        "                   ^~~",
        "/app/src/empty.rb:28: syntax error, unexpected end, expecting '}'",
        "  end",
        "  ^~~",
        "/app/src/empty.rb:32: syntax error, unexpected '}', expecting end-of-input"
      ],
      "rag_lambda": [
        "lambda { |stdout,stderr,status|",
        "  output = stdout + stderr",
        "",
        "  return :amber if /=== ERRORS ===/.match(output)",
        "",
        "  %w( ... ).each do |syntax_error_prefix|",
        "     return :amber sdf if",
        "       /=== FAILURES ===/.match(output) &&",
        "         Regexp.new(\".*:[0-9]+: #{syntax_error_prefix}Error\").match(output)",
        "  end",
        "",
        "  return :green if /=== (\\d+) passed/.match(output)",
        "  return :red",
        "}"
      ]
    }
  }
  ```

- - - -
## GET ready?
Tests if the service is ready to handle requests.
- [JSON-in](#json-in) parameters
  * none
- returns [JSON-out](#json-out) result, keyed on `"ready?"`
  * **true** if the service is ready
  * **false** if the service is not ready
- notes
  * Used as a [Kubernetes](https://kubernetes.io/) readiness probe.
- example
  ```bash     
  $ curl --silent -X GET http://${IP_ADDRESS}:${PORT}/ready?
  {"ready?":false}
  ```

- - - -
## GET alive?
Tests if the service is alive.  
- [JSON-in](#json-in) parameters
  * none
- returns the [JSON-out](#json-out) result, keyed on `"alive?"`
  * **true**
- notes
  * Used as a [Kubernetes](https://kubernetes.io/) liveness probe.  
- example
  ```bash     
  $ curl --silent -X GET http://${IP_ADDRESS}:${PORT}/alive?
  {"alive?":true}
  ```

- - - -
## GET sha
The 40 character git commit sha used to create the Docker image.
- [JSON-in](#json-in) parameters
  * none
- returns the [JSON-out](#json-out) result, keyed on `"sha"`
  * eg `"41d7e6068ab75716e4c7b9262a3a44323b4d1448"`
- example
  ```bash     
  $ curl --silent -X GET http://${IP_ADDRESS}:${PORT}/sha
  {"sha":"41d7e6068ab75716e4c7b9262a3a44323b4d1448"}
  ```

- - - -
# JSON in
- All methods pass any arguments as a json hash in the http request body.
- If there are no arguments you can use `''` (which is the default
  for `curl --data`) instead of `'{}'`.

- - - -
# JSON out      
- All methods return a json hash in the http response body.
- If the method completes, a string key equals the method's name. eg
  ```bash
  $ curl --silent -X GET http://${IP_ADDRESS}:${PORT}/ready?
  { "ready?":true}
  ```
- If the method raises an exception, a string key equals `"exception"`, with
  a json-hash as its value. eg
  ```bash
  $ curl --silent -X POST http://${IP_ADDRESS}:${PORT}/run_cyber_dojo_sh | jq      
  { "exception": {
      "path": "/run_cyber_dojo_sh",
      "body": "",
      "class": "RunnerService",
      "message": "image_name is missing",
      "backtrace": [
        ...
        "/usr/bin/rackup:23:in `<main>'"
      ]
    }
  }
  ```
