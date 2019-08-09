# Agentless::Catalog::Executor

## App Overview

The Agentless Catalog Executor (ACE) provides agentless executions services for tasks and catalogs to Puppet Enterprise (PE). See [developer-docs/api](developer-docs/api.md) for an API spec. See below for development info.

## Code Overview

API entrypoints are in `lib/ace/transport_app.rb`.

Fork isolation is implemented in `lib/ace/fork_utils.rb`

Catalog compilations use the certless [v4 catalog](https://github.com/puppetlabs/puppetserver/blob/master/documentation/puppet-api/v4/catalog.markdown) puppetserver endpoint and expose it through the indirector in `lib/puppet/indirector/catalog/certless.rb`.

## Installation

ACE is built-in to PE as pe-ace-server.

## Development

As ACE is dependent on Puppet Server, there is a docker-compose file in the `spec/` directory which we advise you run before the ACE service to ensure that the certs and keys are valid. For more information, see the [docker documentation](developer-docs/docker.md).

To release a new version, update the version number in `version.rb`, generate a new changelog with `bundle exec rake changelog`, commit the results and run `bundle exec rake release`, which creates a git tag for the version, pushes git commits and tags, and pushes the `.gem` file to [rubygems.org](https://rubygems.org). Released gems are eventually consumed by [ace-vanagon](https://github.com/puppetlabs/ace-vanagon) and promoted into PE.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/puppetlabs/ace. See the `.travis.yml` file for which checks to run on your code before submitting. Always include tests with your changes.
