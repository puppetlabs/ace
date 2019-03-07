# frozen_string_literal: true

require 'ace'
require 'bolt'
require 'bolt/target'
require 'bolt/task'
require 'bolt/inventory'
require 'bolt/task/puppet_server'
require 'bolt_server/file_cache'
require 'json'
require 'json-schema'
require 'sinatra'

module ACE
  class TransportApp < Sinatra::Base
    def initialize(config = nil)
      @config = config

      @schemas = {
        "run_task" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'ace-run_task.json')))
      }
      shared_schema = JSON::Schema.new(JSON.parse(File.read(File.join(__dir__, 'schemas', 'task.json'))),
                                       Addressable::URI.parse("file:task"))
      JSON::Validator.add_schema(shared_schema)

      @executor = Bolt::Executor.new(0, load_config: false)

      @file_cache = BoltServer::FileCache.new(@config).setup

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

    def scrub_stack_trace(result)
      if result.dig(:result, '_error', 'details', 'stack_trace')
        result[:result]['_error']['details'].reject! { |k| k == 'stack_trace' }
      end
      result
    end

    get "/" do
      200
    end

    post "/check" do
      [200, 'OK']
    end

    # run this with "curl -X POST http://0.0.0.0:44633/run_task -d '{}'"
    post '/run_task' do
      content_type :json

      body = JSON.parse(request.body.read)
      #error = validate_schema(@schemas["ace-run_task"], body)
#      return [400, error.to_json] unless error.nil?

      opts = body['target'].merge('protocol' => 'local')

      target = [Bolt::Target.new(body['target']['hostname'], opts)]

      task = Bolt::Task::PuppetServer.new(body['task'], @file_cache)

      parameters = body['parameters'] || {}

      # Since this will only be on one node we can just return the first result
      results = @executor.run_task(target, task, parameters)
      result = scrub_stack_trace(results.first.status_hash)
      [200, result.to_json]
    end
  end
end
