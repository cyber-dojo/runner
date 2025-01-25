# API

- - - -
## POST run_cyber_dojo_sh(id,files,manifest)
Creates a docker container from **manifest**'s **image_name**.  
Inserts **files** into the container in its  `/sandbox` dir.  
Runs `/sandbox/cyber-dojo.sh` for at most **manifest**'s **max_seconds**.
- [JSON-in](#json-in) parameters
  * **id:String** for tracing
  * **files:Hash{filename:String => content:String}** assumed to contain a file called `cyber-dojo.sh`
  * **manifest:Hash** containing
    * **image_name:String** created with [image_builder](https://github.com/cyber-dojo-tools/image_builder)
    * **max_seconds:Integer** between `1` and `20`
  * eg
    ```json
    { "id": "34de2W",
      "files": {
        "cyber-dojo.sh": "coverage3 run --source='.' -m pytest *test*.py\n...",      
        "hiker.py": "class Hiker:...",
        "test_hiker.py": "import hiker\n...",
        "readme.txt": "Your task is to..."
      },
      "manifest": {
        "image_name": "cyberdojofoundation/python_pytest:56fa098",
        "max_seconds": 10
      }
    }
    ```
- returns the [JSON-out](#json-out) result, keyed on `"run_cyber_dojo_sh"`
  * **stdout:Hash** of running `/sandbox/cyber-dojo.sh` truncated to 50K. See example below
  * **stderr:Hash** of running `/sandbox/cyber-dojo.sh` truncated to 50K. See example below
  * **status:String** of running `/sandbox/cyber-dojo.sh` (0 to 255)
  * **outcome:String** see below
  * **created:Hash** text-files created under `/sandbox`, each truncated to 50K
  * **changed:Hash** text-files changed under `/sandbox`, each truncated to 50K
  * **log:Hash** diagnostic info
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
        "status": "2",
        "outcome": "red",
        "created": {
          "report/coverage.txt": {
            "content": "...\nhiker.py            3      0   100%\n...",
            "truncated": false
          }
        },
        "changed": {},
        "log": {...}
      }
    }
    ```
- `"outcome"` equals `"pulling"` if **image_name** is not present on the node.
- `"outcome"` equals `"timed_out"` if `cyber-dojo.sh` failed to complete in **max_seconds**.
- `"outcome"` equals `"red"`, `"amber"`, `"green"`,
    as determined by passing `stdout['content']`, `stderr['content']`, `status` to the Ruby lambda, read from **image_name**, at `/usr/local/bin/red_amber_green.rb`
- `"outcome"` equals `"faulty"` (and adds information to **log**) if
  * `/usr/local/bin/red_amber_green.rb` does not exist in **image_name**
  * eval'ing the lambda raises an exception
  * calling the lambda raises an exception
  * the lambda returns anything other than `red`, `amber`, or `green` (as a string or a symbol)

- - - -
## POST pull_image(id,image_name)
Pulls **image_name** onto the node if not already present.
- [JSON-in](#json-in) parameters
  * **id:String** for tracing
  * **image_name:String**
- returns the [JSON-out](#json-out) result, keyed on `"pull_image"`
  * `"pulled"` if **image_name** is already present on the node.
  * `"pulling"` if **image_name** is not already present on the node, and pulls the image asynchronously.
- example
  ```bash
  JSON='{"id":"34de2W","image_name":"cyberdojofoundation/python_pytest:56fa098"}'
  $ curl --data "${JSON}" --silent --request POST https://${DOMAIN}:${PORT}/pull_image  
  {"pull_image":"pulled"}
  ```


- - - -
## GET alive
Tests if the service is alive.
Used as a [Kubernetes](https://kubernetes.io/) liveness probe.  
- [JSON-in](#json-in) parameters
  * none
- returns the [JSON-out](#json-out) result, keyed on `"alive?"`
  * **true**
- example
  ```bash     
  $ curl --silent --request GET https://${DOMAIN}:${PORT}/alive
  {"alive?":true}
  ```

- - - -
## GET ready
Tests if the service is ready to handle requests.
Used as a [Kubernetes](https://kubernetes.io/) readiness probe.
- [JSON-in](#json-in) parameters
  * none
- returns [JSON-out](#json-out) result, keyed on `"ready?"`
  * **true** if the service is ready
  * **false** if the service is not ready
- example
  ```bash     
  $ curl --silent --request GET https://${DOMAIN}:${PORT}/ready
  {"ready?":false}
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
  $ curl --silent --request GET https://${DOMAIN}:${PORT}/sha
  {"sha":"41d7e6068ab75716e4c7b9262a3a44323b4d1448"}
  ```

- - - -
## JSON in
- All methods pass any arguments as a json hash in the http request body.
- If there are no arguments you can use `''` (which is the default for `curl --data`) instead of `'{}'`.

- - - -
## JSON out      
- All methods return a json hash in the http response body.
- If the method completes, a key equals the method's name. eg
  ```bash
  $ curl --silent --request GET https://${DOMAIN}:${PORT}/ready
  { "ready?":true}
  ```
- If the method raises an exception, a key equals `"exception"`, with
  a json-hash as its value. eg
  ```bash
  $ curl --silent --request POST https://${DOMAIN}:${PORT}/run_cyber_dojo_sh | jq      
  { "exception": {
      "path": "/run_cyber_dojo_sh",
      "body": "",
      "class": "Runner",
      "message": "missing arguments: :id, :files, :manifest",
      "backtrace": [
        "/app/code/dispatcher.rb:35:in `rescue in call'",
        "/app/code/dispatcher.rb:20:in `call'",
        "/app/code/rack_dispatcher.rb:17:in `call'",
        "/usr/lib/ruby/gems/2.7.0/gems/rack-2.2.3/lib/rack/deflater.rb:44:in `call'",
        "/usr/lib/ruby/gems/2.7.0/gems/puma-4.3.5/lib/puma/configuration.rb:228:in `call'",
        "/usr/lib/ruby/gems/2.7.0/gems/puma-4.3.5/lib/puma/server.rb:713:in `handle_request'",
        "/usr/lib/ruby/gems/2.7.0/gems/puma-4.3.5/lib/puma/server.rb:472:in `process_client'",
        "/usr/lib/ruby/gems/2.7.0/gems/puma-4.3.5/lib/puma/server.rb:328:in `block in run'",
        "/usr/lib/ruby/gems/2.7.0/gems/puma-4.3.5/lib/puma/thread_pool.rb:134:in `block in spawn_thread'"
      ]
    }
  }
  ```
