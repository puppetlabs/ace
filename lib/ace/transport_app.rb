# frozen_string_literal: true

require 'ace'
require 'ace/executor'
require 'bolt/target'
require 'bolt/task'
require 'json'
require 'json-schema'
require 'sinatra'

module ACE
  class TransportApp < Sinatra::Base
    def initialize(config = nil)
      @config = config
      @executor = ACE::Executor.new('production')

      @schemas = {
        "ssh-run_task" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'ssh-run_task.json')))
      }
      shared_schema = JSON::Schema.new(JSON.parse(File.read(File.join(__dir__, 'schemas', 'task.json'))),
                                       Addressable::URI.parse("file:task"))
      JSON::Validator.add_schema(shared_schema)

      super(nil)
    end

    def validate_schema(schema, body)
      schema_error = JSON::Validator.fully_validate(schema, body)
      if schema_error.any?
        ACE::Error.new("There was an error validating the request body.",
                       'ace/schema-error',
                       schema_error)
      end
    end

    get "/" do
      200
    end

    # run this with "curl -X POST http://0.0.0.0:9292/run_task -d '{}'"
    post '/run_task' do
      content_type :json

      body = JSON.parse(request.body.read)
      error = validate_schema(@schemas["ssh-run_task"], body)
      return [400, error.to_json] unless error.nil?

      target = [Bolt::Target.new(body['target']['hostname'], body['target'])]

      # originally this was a Bolt::Task::PuppetServer; simplified here for hacking
      task = Bolt::Task.new(body['task'])

      parameters = body['parameters'] || {}

      result = @executor.run_task(target, task, parameters)

      # error = validate_schema(@schemas["ssh-run_task"], body)
      # return [400, error.to_json] unless error.nil?

      # opts = body['target']
      # if opts['private-key-content']
      #   opts['private-key'] = { 'key-data' => opts['private-key-content'] }
      #   opts.delete('private-key-content')
      # end

      # target = [Bolt::Target.new(body['target']['hostname'], opts)]

      # task = Bolt::Task::PuppetServer.new(body['task'], @file_cache)

      # parameters = body['parameters'] || {}

      # # Since this will only be on one node we can just return the first result
      # results = @executor.run_task(target, task, parameters)
      # result = scrub_stack_trace(results.first.status_hash)
      [200, result.to_json]
    end
  end
end
