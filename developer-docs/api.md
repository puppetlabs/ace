# ACE API

## Overview
ACE provides 2 APIs to enable the execution or Tasks and Catalog compilation for a remote target.

## API Endpoints
Each API endpoint accepts a request as described below. The request body must be a JSON object.

### POST /run_task
- `target`: [RSAPI Transport Object](#rsapi-transport-object), *required* - Target information to run task on.
- `task`: [Task Object](#task-object), *required* - Task to run on target.
- `parameters`: Object, *optional* - JSON formatted parameters to be provided to task.

For example, the following runs the 'commit' task on `fw.example.net`:
```
{
  "target":{
    "remote-transport":"panos",
    "host":"fw.example.net",
    "user":"foo",
    "password":"wibble"
  },
  "task":{
    "metadata":{},
    "name":"panos::commit",
    "files":[
      {
        "filename":"commit.rb",
        "sha256":"c5abefbdecee006bd65ef6f625e73f0ebdd1ef3f1b8802f22a1b9644a516ce40",
        "size_bytes":640,
        "uri":{
          "path":"/puppet/v3/file_content/tasks/panos/commit.rb",
          "params":{
            "environment":"production"
          }
        }
      }
    ]
  },
  "parameters":{
    "message":"Hello world"
  }
}
```

#### Response
If the task runs the response will have status 200.
The response will be a standard bolt Result JSON object.


### POST /execute_catalog
- `target`: [RSAPI Transport Object](#rsapi-transport-object), *required* - Target information to execute the catalog on.
- `compiler`: [Compiler Request Object](#compiler-request-object), *required* - Details on the requested compile.

For example, the following will compile and execute a catalog on fw.example.net:
```
{
  "target":{
    "remote-transport":"panos",
    "host":"fw.example.net",
    "user":"foo",
    "password":"wibble"
  },
  "compiler":{
    "certname":"fw.example.net",
    "environment":"development",
    "transaction_uuid":"<uuid string>",
    "job_id":"<id string>"
  }
}
```

For pre-Transport devices (currently F5), a uri can be sent:

```
{
  "target":{
    "remote-transport":"f5",
    "uri":"https://foo:wibble@f5.example.net/"
  },
  "compiler":{
    "certname":"f5.example.net",
    "environment":"development",
    "transaction_uuid":"<uuid string>",
    "job_id":"<id string>"
  }
}
```

#### Response
TBD based on orchestrator's needs for feedback.

## Data Object Definitions

### RSAPI Transport Object
The `target` is a JSON object which reflects the schema of the `remote-transport`.
e.g. If `remote-transport` is `panos`, the object should validate against the panos transport schema.

Read more about [Transports](https://github.com/puppetlabs/puppet-resource_api#remote-resources) in the Resource API README. The `target` will contain both connection info and bolt's keywords for connection management.

### Compiler Request Object
The `compiler` is a JSON object which contains parameters regarding the compilation of the catalog for this request. It contains four attributes that have the same definition as the attributes of the same name in the [puppet server catalog API](https://github.com/puppetlabs/puppetserver/blob/master/documentation/puppet-api/v4/catalog.markdown):

* `certname`
* `environment`
* `transaction_uuid`
* `job_id`

### Task Object
This is a copy of [bolt's task object](https://github.com/puppetlabs/bolt/blob/master/developer-docs/bolt-api-servers.md#task-object)


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
