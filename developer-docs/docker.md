# Docker Docs

## Setup

[Docker-compose installation](https://docs.docker.com/compose/install/) would need to be followed and setup in order to use the ACE containers for development.


The ACE compose file is dependent on a Docker network created when launching the Puppetserver and PuppetDB containers within the `spec/` directory, the network will default to `spec_default`, since the containers are built from the `spec/` directory they will be assigned the `<folder>_default` network.

As the ACE container is build outside of the `spec/` directory it would not be able to create the `spec_default` network. This can be created manually through:

```
docker network create spec_default
```

Once this is done the ACE container can be launched by executing the following within the root folder:

```
docker-compose up -d --build
```

This will take some time as it needs to perform the initial build of fetching the images and running through the build.

Navigate to the `spec/` folder and build the Puppetserver and PuppetDB containers using the same command. The Puppetserver will take some time to start and typically using the following command to verify that it is ready:

```
docker logs --follow spec_puppet_1
```

Once the Puppetserver is ready, the following message is reported:

```
2019-03-18 15:42:19,964 INFO  [p.s.m.master-service] Puppet Server has successfully started and is now ready to handle requests
2019-03-18 15:42:19,965 INFO  [p.s.l.legacy-routes-service] The legacy routing service has successfully started and is now ready to handle requests
```

On Linux, ensure that you have access to all volumes:

```
sudo chmod a+rx -R volumes/
```

At this point it is required to generate certs for the `aceserver`, this can be achieved though:

`docker exec spec_puppet_1 puppetserver ca generate --certname aceserver --subject-alt-names localhost,aceserver,ace_aceserver_1,spec_puppetserver_1,ace_server,puppet_server,spec_aceserver_1,puppetdb,spec_puppetdb_1,0.0.0.0,puppet`

On Linux, ensure that you have access to the newly created files:

```
sudo chmod a+rx -R volumes/
```

Reasoning for this is that it makes it easier to ensure that the cert names are consistent across environments.

## Verifying the services

[Postman](https://www.getpostman.com/) is advisable to verify that the endpoints are configured. In order to set up Postman, navigate to Settings > Certificates and add client certificates for hosts `0.0.0.0:8140` and `0.0.0.0:44633` where the CRT file points to `spec/volumes/puppet/ssl/certs/aceserver.pem` and Key file points to `spec/volumes/puppet/ssl/private_keys/aceserver.pem`

*Note*: These cert and key files will only be created when the PuppetServer container has finished initalising.

### PuppetServer /tasks/:module/:task

```
https://0.0.0.0:8140/puppet/v3/tasks/:module/:task?environment=production
```

Is the endpoint to get the task metadata from a PuppetServer, i.e.

```
GET https://0.0.0.0:8140/puppet/v3/tasks/panos/apikey?environment=production

RESPONSE
{
    "metadata": {
        "description": "Retrieve a PAN-OS apikey",
        "files": [
            ...
        ],
        "parameters": {},
        "puppet_task_version": 1,
        "remote": true,
        "supports_noop": false
    },
    "name": "panos::apikey",
    "files": [
        ...
    ]
}
```

This can be used to construct the request body that will be used to execute the [ACE `/run_task`](#ace-runtask) endpoint.

### ACE /run_task

```
POST https://0.0.0.0:44633/run_task
BODY {
	"target": {
		"remote-transport": "panos",
		"name":"pavm",
		"hostname": "vvtzckq3vzx995w.delivery.puppetlabs.net",
		"user": "admin",
		"password": "admin",
		"ssl": false
	},
	"task": {
    "metadata": {
        "description": "Retrieve a PAN-OS apikey",
        "files": [
            ...
        ],
        "parameters": {},
        "puppet_task_version": 1,
        "remote": true,
        "supports_noop": false
    },
    "name": "panos::apikey",
    "files": [
        ...
    ]
}}

RESPONSE
{
    "node": "vvtzckq3vzx995w.delivery.puppetlabs.net",
    "status": "success",
    "result": {
        "apikey": "LUFRPT14MW5xOEo1R09KVlBZNnpnemh0VHRBOWl6TGM9bXcwM3JHUGVhRlNiY0dCR0srNERUQT09"
    }
}
```

Running the containers through Docker does have the benefit that the containers will be a better representation of how the ACE service will work in PE, however for developing and verifying changes it can be considered slow as changes may require the ACE container to be rebuilt which can take some time, an alternative approach for local development is [running the service locally](#running-ace-locally), this way the Puppetserver and PuppetDB containers are only required to be running.

## Running ACE locally

The ACE service can also be ran directly through Puma rather than building the container, this has the benefits of being able to specifying local changes of Bolt within the Gemfile rather than having to make the changes in the container, or committing the changes and rebuilding the containers which can take some time.

When running locally through Puma there is a caveat on the tasks that are being executed and a possible conflict with the version of Ruby on the local installation, where solutions are highlighted in the [incorrect Puppet Ruby version](#incorrect-puppet-ruby-version).

Launching the service locally can be achieved by running the following:

```
ACE_CONF=config/local.conf bundle exec puma -C config/transport_tasks_config.rb
```

### Incorrect Puppet Ruby version

The tasks typically used in networking modules have a shebang referencing the Puppet Ruby, there are two approaches to getting around this.

When constructing requests to be sent to ACE, in the target hash the interpreter can be specified, i.e.

```
{
   "target":{
      "remote-transport":"panos",
      "name":"pavm",
      "interpreters":{
         ".rb":"/Users/thomas.franklin/.rbenv/versions/2.5.1/bin/ruby"
      }
   },
   "task": {hash from puppetserver /tasks endpoint}
}
```

Although this would need to be included in every request - a 'permanent' solution would be to symlink the Puppet Ruby to the development version of Ruby, i.e.

```
sudo ln -svf $(bundle exec which ruby) /opt/puppetlabs/puppet/bin/ruby
```
