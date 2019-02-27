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
bundle exec puma -C puma_config.rb
```

## Development

After checking out the repo, run ACE using `bundle exec puma -p 44633 -C puma_config.rb`. Alternatively use `docker-compose up -d --build` to build and run an ACE container.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/puppetlabs/agentless-catalog-executor.
