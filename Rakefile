# frozen_string_literal: true

require "bundler/gem_tasks"
require 'rubocop/rake_task'

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end

task default: %i[rubocop spec license_finder]

#### RSPEC ####
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc 'Run RSpec code examples with coverage collection'
  task :coverage do
    ENV['COVERAGE'] = 'yes'
    Rake::Task['spec'].execute
  end
end

#### LICENSE_FINDER ####
desc 'Check for unapproved licenses in dependencies'
task(:license_finder) do
  unless system('license_finder --decisions-file=.dependency_decisions.yml')
    raise(StandardError, 'Unapproved license(s) found on dependencies')
  end
end

#### CHANGELOG ####
begin
  require 'github_changelog_generator/task'
  GitHubChangelogGenerator::RakeTask.new :changelog do |config|
    require 'ace/version'
    config.future_release = "v#{ACE::VERSION}"
    config.header = "# Changelog\n\n" \
      "All significant changes to this repo will be summarized in this file.\n"
    # config.include_labels = %w[enhancement bug]
    config.user = 'puppetlabs'
    config.project = 'ace'
  end
rescue LoadError
  desc 'Install github_changelog_generator to get access to automatic changelog generation'
  task :changelog do
    raise 'Install github_changelog_generator to get access to automatic changelog generation'
  end
end
