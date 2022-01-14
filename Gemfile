# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :tests do
  gem 'codecov'
  gem 'license_finder' if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.4.0')
  gem 'simplecov-console'
  gem 'webmock'
end

group :development do
  # gem 'bolt', git: 'https://github.com/puppetlabs/bolt', branch: 'master'
  # activesupport 7 bumped the minimum Ruby version to 2.7. We can remove this
  # once we're on that version.
  gem "activesupport", "~> 6.0"
  gem 'github_changelog_generator', '~> 1.14'
  gem 'pry-byebug'
  gem 'rubocop-rspec'
end

# Specify your gem's dependencies in agentless-catalog-executor.gemspec
gemspec
