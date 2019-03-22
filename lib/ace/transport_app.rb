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
        "run_task" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'ace-run_task.json'))),
        "execute_catalog" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'ace-execute_catalog.json')))
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

    post "/check" do
      [200, 'OK']
    end

    # run this with "curl -X POST http://0.0.0.0:44633/run_task -d '{}'"
    post '/run_task' do
      content_type :json

      body = JSON.parse(request.body.read)
      error = validate_schema(@schemas["run_task"], body)
      return [400, error.to_json] unless error.nil?

      # grab the transport connection_info
      connection_info = Hash[body['target'].map { |k, v| [k.to_sym, v] }] # may contain sensitive data

      # originally this was a Bolt::Task::PuppetServer; simplified here for hacking
      task = Bolt::Task.new(body['task'])

      parameters = body['parameters'] || {}

      result = @executor.run_task(connection_info, task, parameters)

      [result.first, result.last.to_json]
    end

    post '/execute_catalog' do
      content_type :json

      body = JSON.parse(request.body.read)
      error = validate_schema(@schemas["execute_catalog"], body)
      return [400, error.to_json] unless error.nil?

      # simulate expected error cases
      if body['compiler']['certname'] == 'fail.example.net'
        [200, { _error: {
          msg: 'catalog compile failed',
          kind: 'puppetlabs/ace/compile_failed',
          details: 'upstream api errors go here'
        } }.to_json]
      elsif body['compiler']['certname'] == 'credentials.example.net'
        [200, { _error: {
          msg: 'target specification invalid',
          kind: 'puppetlabs/ace/target_spec',
          details: 'upstream api errors go here'
        } }.to_json]
      elsif body['compiler']['certname'] == 'reports.example.net'
        [200, { _error: {
          msg: 'report submission failed',
          kind: 'puppetlabs/ace/reporting_failed',
          details: 'upstream api errors go here'
        } }.to_json]
      else
        [200, '{}']
      end
    end
  end
end
