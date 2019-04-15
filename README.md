# Agentless::Catalog::Executor

## Installation

ACE is installed as pe-ace-server as part of Puppet Enterprise.

## Usage

For development or experimenting, run the puma server to get an instance started:

```
ACE_CONF=config/local.conf bundle exec puma -C config/transport_tasks_config.rb
```

## Development

As ACE is dependent on a PuppetServer, there is a docker-compose file within the `spec/` directory which is advisable to run first to ensure that the certs and keys are valid before running the ACE service, more information can be found in the [docker documentation](developer-docs/docker).

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org). Released gems will eventually be consumed by [ace-vanagon](https://github.com/puppetlabs/ace-vanagon) and promoted into PE.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/puppetlabs/ace. See the `.travis.yml` file for checks to run on your code before submitting. Please always include tests with your changes.
