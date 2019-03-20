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

## Data Object Definitions

### RSAPI Transport Object
The `target` is a JSON object which reflects the schema of the `remote-transport`.
e.g. If `remote-transport` is `panos`, the object should validate against the panos transport schema.

Read more about [Transports](https://github.com/puppetlabs/puppet-resource_api#remote-resources) in the Resource API README. The `target` will contain both connection info and bolt's keywords for connection management.

### Task Object
This is a copy of [bolt's task object](https://github.com/puppetlabs/bolt/blob/master/developer-docs/bolt-api-servers.md#task-object)

### Response
If the task runs the response will have status 200.
The response will be a standard bolt Result JSON object.


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
