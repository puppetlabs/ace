# Agentless::Catalog::Executor

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'agentless-catalog-executor'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install agentless-catalog-executor

## Usage

Run the puma server to get an instance started:

```
ACE_CONF=config/local.conf bundle exec puma -C config/transport_tasks_config.rb
```

## Development

After checking out the repo, ACE can be ran using `ACE_CONF=config/local.conf bundle exec puma -C config/transport_tasks_config.rb`. As ACE is dependent on a PuppetServer, there is a docker-compose file within the `spec/` directory which is advisable to run first to ensure that the certs and keys are valid before running the ACE service, more information can be found in the [docker documentation](developer-docs/docker).

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/puppetlabs/agentless-catalog-executor.
