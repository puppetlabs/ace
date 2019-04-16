# Agentless::Catalog::Executor

## Installation

The Agentless Catalog Executor (ACE) is built-in to Puppet Enterprise (PE) as pe-ace-server.

## Usage

To spin up an instance for development, run the puma server:

```
ACE_CONF=config/local.conf bundle exec puma -C config/transport_tasks_config.rb
```

## Development

As ACE is dependent on Puppet Server, there is a docker-compose file in the `spec/` directory which we advise you run before  the ACE service to ensure that the certs and keys are valid. For more information, see the [docker documentation](developer-docs/docker).

To release a new version, update the version number in `version.rb` and  run `bundle exec rake release`, which creates a git tag for the version, pushes git commits and tags, and pushes the `.gem` file to [rubygems.org](https://rubygems.org). Released gems are eventually consumed by [ace-vanagon](https://github.com/puppetlabs/ace-vanagon) and promoted into PE.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/puppetlabs/ace. See the `.travis.yml` file for which checks to run on your code before submitting. Always include tests with your changes.
