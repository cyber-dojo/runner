# API

- - - -
## GET run_cyber_dojo_sh(id,files,manifest)
Creates a docker container from **manifest**'s **image_name**, inserts **files** into the
container in its  `/sandbox` dir, runs `/sandbox/cyber-dojo.sh` for at most
**manifest**'s **max_seconds**.
- [JSON-in](#json-in) parameters
  * **id:String** for tracing
  * **files:Hash{filename:String => content:String}** assumed to contain a file called `"cyber-dojo.sh"`
  * **manifest:Hash** containing
    * **image_name:String** created with [image_builder](https://github.com/cyber-dojo-languages/image_builder)
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
        "image_name": "cyberdojofoundation/python_pytest",
        "max_seconds": 10
      }
    }
    ```
- returns the [JSON-out](#json-out) result, keyed on `"run_cyber_dojo_sh"`
  * **stdout:Hash** of running `/sandbox/cyber-dojo.sh` truncated to 50K
  * **stderr:Hash** of running `/sandbox/cyber-dojo.sh` truncated to 50K
  * **status:String** of running `/sandbox/cyber-dojo.sh` (0 to 255)
  * **colour:String** see below
  * **timed_out:Boolean** true if execution completed in **max_seconds**
  * **created:Hash** text-files created under `/sandbox`, each truncated to 50K
  * **deleted:Array[String]** names of text-files deleted from `/sandbox`
  * **changed:Hash** text-files changed under `/sandbox`, each truncated to 50K
  * **log:String** diagnostic info
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
        "status": '2',
        "timed_out": false,
        "colour": "red",
        "created": {
          "report/coverage.txt": {
            "content": "...\nhiker.py            3      0   100%\n...",
            "truncated": false
          }
        },
        "deleted": [],
        "changed": {},
        "log": ""
      }
    }
    ```
- `"colour"` equals `"red"`, `"amber"`, `"green"`, or `"faulty"`
    as determined by passing `stdout['content']`, `stderr['content']`, `status` to the Ruby lambda, read from **image_name**, at `/usr/local/bin/red_amber_green.rb`
  * if `/usr/local/bin/red_amber_green.rb` does not exist in **image_name**, then `"colour"` is `"faulty"`.
  * if eval'ing the lambda raises an exception, then `"colour"` is `"faulty"`.
  * if calling the lambda raises an exception, then `"colour"` is `"faulty"`.
  * if calling the lambda returns anything other than `red`, `amber`, or `green` (as a string or a symbol)
    then `"colour"` is `"faulty"`.
- if `"colour"` is `"faulty"`, also returns information in the **log**

- - - -
## GET ready?
Tests if the service is ready to handle requests.
Used as a [Kubernetes](https://kubernetes.io/) readiness probe.
- [JSON-in](#json-in) parameters
  * none
- returns [JSON-out](#json-out) result, keyed on `"ready?"`
  * **true** if the service is ready
  * **false** if the service is not ready
- example
  ```bash     
  $ curl --silent -X GET http://${IP_ADDRESS}:${PORT}/ready?
  {"ready?":false}
  ```

- - - -
## GET alive?
Tests if the service is alive.
Used as a [Kubernetes](https://kubernetes.io/) liveness probe.  
- [JSON-in](#json-in) parameters
  * none
- returns the [JSON-out](#json-out) result, keyed on `"alive?"`
  * **true**
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
## JSON in
- All methods pass any arguments as a json hash in the http request body.
- If there are no arguments you can use `''` (which is the default
  for `curl --data`) instead of `'{}'`.

- - - -
## JSON out      
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
