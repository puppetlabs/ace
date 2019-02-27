# ACE API

## Overview
ACE provides 2 APIs to enable the execution or Tasks and Catalog compilation for a remote target.

## API Endpoints
Each API endpoint accepts a request as described below. The request body must be a JSON object.

### POST /run_task
- `target`: [RSAPI Transport Object](#rsapi-transport-object), *required* - Target information to run task on.
- `task`: [Task Object](#task-object), *required* - Task to run on target.
- `parameters`: Object, *optional* - JSON formatted parameters to be provided to task.

For example, the following runs the 'echo' task on linux_target.net:
```
{
  "target": {
    "remote-transport": "panos",
    "user": "foo",
    "password": "wibble"
  },
  "task": {
    "metadata":{},
    "name":"sample::echo",
    "files":[{
      "filename":"echo.sh",
      "sha256":"c5abefbdecee006bd65ef6f625e73f0ebdd1ef3f1b8802f22a1b9644a516ce40",
      "size_bytes":64,
      "uri":{
        "path":"/puppet/v3/file_content/tasks/sample/echo.sh",
        "params":{
          "environment":"production"}
      }
    }]
  },
  "parameters": {
    "message": "Hello world"
  }
}
```

### RSAPI Transport Object
The `target` is a JSON object which reflects the schema of the `remote-transport`.
e.g. If `remote-transport` is `panos`, the object should validate against the panos transport schema.

### Task Object
This is nearly identical to the [task detail JSON
object](https://github.com/puppetlabs/puppetserver/blob/master/documentation/puppet-api/v3/task_detail.json)
from [puppetserver](https://github.com/puppetlabs/puppetserver), with an
additional `file_content` key.

See the [schema](../lib/ace/schemas/task.json)
The task is a JSON object which includes the following keys:

#### Name

The name of the task

#### Metadata
The metadata object is optional, and contains metadata about the task being run. It includes the following keys:

- `description`: String, *optional* - The task description from it's metadata.
- `parameters`: Object, *optional* - A JSON object whose keys are parameter names, and whose values are JSON objects with 2 keys:
    - `description`: String, *optional* - The parameter description.
    - `type`: String, *optional* - The type the parameter should accept.
    - `sensitive`: Boolean, *optional* - Whether the task runner should treat the parameter value as sensitive
    - `input_method`: String, *optional* - What input method should be used to pass params to task (stdin, environment, powershell)

#### Files
The files array is required, and contains details about the files the task needs as well as how to get them. Array items should be objects with the following keys:
- `uri`: Object, *required* - Information on how to request task files
    - `path`: String, *required* - Relative URI for requesting task content
    - `params`: Object, *required* - Query parameters for locating task data
        - `environment`: String, *required* - Environment task files are in
- `sha256`: String, *required* - Shasum of the file contents
- `filename`: String, *required* - File name including extension
- `size`: Number, *optional* - Size of file in Bytes

### Response
If the task runs the response will have status 200.
The response will be a standard ace Result JSON object.


## Running ACE in a container
*Recommended*

From your checkout of ACE start the docker-compose to run ACE

```
docker-compose up -d --build
```

You can now make a curl request to ACE which should respond with 'OK'

```
run this with "curl -X POST http://0.0.0.0:44633/check
```

## Running from source

From your checkout of ACE run

```
bundle exec puma -p 44633 -C puma_config.rb
```

You can now make a curl request to bolt which should respond with 'OK'
```
run this with "curl -X POST http://0.0.0.0:44633/check
```