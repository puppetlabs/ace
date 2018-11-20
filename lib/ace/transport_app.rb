# frozen_string_literal: true

require 'sinatra'
require 'ace/executor'
require 'bolt/target'

module ACE
  class TransportApp < Sinatra::Base
    def initialize(config = nil)
      @config = config
      @executor = ACE::Executor.new('production')

      super(nil)
    end

    get "/" do
      200
    end

    # run this with "curl -X POST http://0.0.0.0:9292/run_task -d '{}'"
    post '/run_task' do
      content_type :json

      body = JSON.parse(request.body.read)

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
