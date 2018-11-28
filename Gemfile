# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }


group :tests do
  gem 'codecov'
  gem 'simplecov-console'
end

group :development do
  gem 'github_changelog_generator', '~> 1.14'
  gem 'pry-byebug'
end

# Specify your gem's dependencies in agentless-catalog-executor.gemspec
gemspec
