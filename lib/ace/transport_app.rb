# frozen_string_literal: true

require 'ace/error'
require 'ace/fork_util'
require 'ace/puppet_util'
require 'ace/configurer'
require 'ace/plugin_cache'
require 'bolt_server/file_cache'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/target'
require 'bolt/task/puppet_server'
require 'json-schema'
require 'json'
require 'sinatra'
require 'puppet/util/network_device/base'

module ACE
  class TransportApp < Sinatra::Base
    def initialize(config = nil)
      @config = config
      @executor = Bolt::Executor.new(0)
      tasks_cache_dir = File.join(@config['cache-dir'], 'tasks')
      @file_cache = BoltServer::FileCache.new(@config.data.merge('cache-dir' => tasks_cache_dir)).setup
      environments_cache_dir = File.join(@config['cache-dir'], 'environment_cache')
      @plugins = ACE::PluginCache.new(environments_cache_dir).setup

      @schemas = {
        "run_task" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'ace-run_task.json'))),
        "execute_catalog" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'ace-execute_catalog.json')))
      }
      shared_schema = JSON::Schema.new(JSON.parse(File.read(File.join(__dir__, 'schemas', 'task.json'))),
                                       Addressable::URI.parse("file:task"))
      JSON::Validator.add_schema(shared_schema)

      ACE::PuppetUtil.init_global_settings(config['ssl-ca-cert'],
                                           config['ssl-ca-crls'],
                                           config['ssl-key'],
                                           config['ssl-cert'],
                                           config['cache-dir'],
                                           URI.parse(config['puppet-server-uri']))

      super(nil)
    end

    # Initialises the puppet target.
    # @param certname   The certificate name of the target.
    # @param transport  The transport provider of the target.
    # @param target     Target connection hash or legacy connection URI
    # @return [Puppet device instance] Returns Puppet device instance
    # @raise  [puppetlabs/ace/invalid_param] If nil parameter or no connection detail found
    # @example Connect to device.
    #   init_puppet_target('test_device.domain.com', 'panos',  JSON.parse("target":{
    #                                                                       "remote-transport":"panos",
    #                                                                       "host":"fw.example.net",
    #                                                                       "user":"foo",
    #                                                                       "password":"wibble"
    #                                                                     }) ) => panos.device
    def self.init_puppet_target(certname, transport, target)
      unless target
        raise ACE::Error.new("There was an error parsing the Puppet target. 'target' not found",
                             'puppetlabs/ace/invalid_param')
      end
      unless certname
        raise ACE::Error.new("There was an error parsing the Puppet compiler details. 'certname' not found",
                             'puppetlabs/ace/invalid_param')
      end
      unless transport
        raise ACE::Error.new("There was an error parsing the Puppet target. 'transport' not found",
                             'puppetlabs/ace/invalid_param')
      end

      if target['uri']
        if target['uri'] =~ URI::DEFAULT_PARSER.make_regexp
          # Correct URL
          url = target['uri']
        else
          raise ACE::Error.new("There was an error parsing the URI of the Puppet target",
                               'puppetlabs/ace/invalid_param')
        end
      else
        url = Hash[target.map { |(k, v)| [k.to_sym, v] }]
        url.delete(:"remote-transport")
      end

      device_struct = Struct.new(:provider, :url, :name, :options)
      # Return device
      Puppet::Util::NetworkDevice.init(device_struct.new(transport,
                                                         url,
                                                         certname,
                                                         {}))
    end

    def scrub_stack_trace(result)
      if result.dig(:result, '_error', 'details', 'stack_trace')
        result[:result]['_error']['details'].reject! { |k| k == 'stack_trace' }
      end
      if result.dig(:result, '_error', 'details', 'backtrace')
        result[:result]['_error']['details'].reject! { |k| k == 'backtrace' }
      end
      result
    end

    def validate_schema(schema, body)
      schema_error = JSON::Validator.fully_validate(schema, body)
      if schema_error.any?
        raise ACE::Error.new("There was an error validating the request body.",
                             'puppetlabs/ace/schema-error',
                             schema_error: schema_error.first)
      end
    end

    def nest_metrics(metrics)
      Hash[metrics.fetch('resources', {}).values.map do |name, _human_name, value|
        [name, value]
      end]
    end

    # returns a hash of trusted facts that will be used
    # to request a catalog for the target
    def self.trusted_facts(certname)
      # if the certname is a valid FQDN, it will split
      # it in to the correct hostname.domain format
      # otherwise hostname will be the certname and domain
      # will be empty
      hostname, domain = certname.split('.', 2)
      trusted_facts = {
        "authenticated": "remote",
        "extensions": {},
        "certname": certname,
        "hostname": hostname
      }
      trusted_facts[:domain] = domain if domain
      trusted_facts
    end

    get "/" do
      200
    end

    post "/check" do
      [200, 'OK']
    end

    # :nocov:
    if ENV['RACK_ENV'] == 'dev'
      get '/admin/gc' do
        GC.start
        200
      end
    end

    get '/admin/gc_stat' do
      [200, GC.stat.to_json]
    end
    # :nocov:

    # run this with "curl -X POST http://0.0.0.0:44633/run_task -d '{}'"
    post '/run_task' do
      content_type :json

      begin
        body = JSON.parse(request.body.read)
        validate_schema(@schemas["run_task"], body)
        opts = body['target'].merge('protocol' => 'remote')

        # This is a workaround for Bolt due to the way it expects to receive the target info
        # see: https://github.com/puppetlabs/bolt/pull/915#discussion_r268280535
        # Systems calling into ACE will need to determine the nodename/certname and pass this as `name`
        target = [Bolt::Target.new(body['target']['host'] || body['target']['name'], opts)]
      rescue ACE::Error => e
        request_error = {
          "node": target,
          "target": target,
          "action": nil,
          "object": nil,
          "status": "failure",
          "result": {
            "_error": e.to_h
          }
        }
        return [400, request_error.to_json]
      rescue JSON::ParserError => e
        request_error = {
          "node": target,
          "target": target,
          "action": nil,
          "object": nil,
          "status": "failure",
          "result": {
            "_error": ACE::Error.to_h(e.message,
                                      'puppetlabs/ace/request_exception',
                                      class: e.class, backtrace: e.backtrace).to_h
          }
        }
        return [400, request_error.to_json]
      rescue StandardError => e
        request_error = {
          "node": target,
          "target": target,
          "action": nil,
          "object": nil,
          "status": "failure",
          "result": {
            "_error": ACE::Error.to_h(e.message,
                                      'puppetlabs/ace/execution_exception',
                                      class: e.class, backtrace: e.backtrace).to_h
          }
        }
        return [500, request_error.to_json]
      end

      begin
        inventory = Bolt::Inventory.new(nil)

        target.first.inventory = inventory

        task = Bolt::Task::PuppetServer.new(body['task'], @file_cache)

        parameters = body['parameters'] || {}

        result = ForkUtil.isolate do
          # Since this will only be on one node we can just return the first result
          results = @executor.run_task(target, task, parameters)
          scrub_stack_trace(results.first.status_hash)
        end
        [200, result.to_json]
      rescue Exception => e # rubocop:disable Lint/RescueException
        # handle all the things and make it obvious what happened
        process_error = {
          "node": target,
          "target": target,
          "action": nil,
          "object": nil,
          "status": "failure",
          "result": {
            "_error": ACE::Error.to_h(e.message,
                                      'puppetlabs/ace/processing_exception',
                                      class: e.class, backtrace: e.backtrace).to_h
          }
        }
        return [500, process_error.to_json]
      end
    end

    post '/execute_catalog' do
      content_type :json

      begin
        body = JSON.parse(request.body.read)
        validate_schema(@schemas["execute_catalog"], body)

        environment = body['compiler']['environment']
        enforce_environment = body['compiler']['enforce_environment']
        if environment == '' && !enforce_environment
          environment = 'production'
        elsif environment == '' && enforce_environment
          raise ACE::Error.new('You MUST provide an `environment` when `enforce_environment` is set to true',
                               'puppetlabs/ace/execute_catalog')
        end
        certname = body['compiler']['certname']
        trans_id = body['compiler']['transaction_uuid']
        job_id = body['compiler']['job_id']
      rescue ACE::Error => e
        request_error = {
          status: 'failure',
          result: {
            _error: e.to_h
          }
        }
        return [400, request_error.to_json]
      rescue StandardError => e
        request_error = {
          status: 'failure',
          result: {
            _error: ACE::Error.to_h(e.message,
                                    'puppetlabs/ace/request_exception',
                                    class: e.class, backtrace: e.backtrace)
          }
        }
        return [400, request_error.to_json]
      end

      begin
        run_result = @plugins.with_synced_libdir(environment, enforce_environment, certname) do
          ACE::TransportApp.init_puppet_target(certname, body['target']['remote-transport'], body['target'])

          # Apply compiler flags for Configurer
          Puppet.settings[:noop] = body['compiler']['noop'] || false
          # grab the current debug level
          current_log_level = Puppet.settings[:log_level] if body['compiler']['debug']
          # apply debug level if its specified
          Puppet.settings[:log_level] = :debug if body['compiler']['debug']
          Puppet.settings[:trace] = body['compiler']['trace'] || false
          Puppet.settings[:evaltrace] = body['compiler']['evaltrace'] || false

          configurer = ACE::Configurer.new(body['compiler']['transaction_uuid'], body['compiler']['job_id'])
          options = { transport_name: certname,
                      environment: environment,
                      network_device: true,
                      pluginsync: false,
                      trusted_facts: ACE::TransportApp.trusted_facts(certname) }
          configurer.run(options)
          # return logging level back to original
          Puppet.settings[:log_level] = current_log_level if body['compiler']['debug']
          # `options[:report]` gets populated by configurer.run with the report of the run with a
          # Puppet::Transaction::Report instance
          # see https://github.com/puppetlabs/puppet/blob/c956ad95fcdd9aabb28e196b55d1f112b5944777/lib/puppet/configurer.rb#L211
          report = options[:report]
          # remember that this hash gets munged by fork's json serialising
          {
            'time' => report.time,
            'transaction_uuid' => trans_id,
            'environment' => report.environment,
            'status' => report.status,
            'metrics' => nest_metrics(report.metrics),
            'job_id' => job_id
          }
        end
      rescue ACE::Error => e
        process_error = {
          certname: certname,
          status: 'failure',
          result: {
            _error: e.to_h
          }
        }
        return [400, process_error.to_json]
      rescue StandardError => e
        process_error = {
          certname: certname,
          status: 'failure',
          result: {
            _error: ACE::Error.to_h(e.message,
                                    'puppetlabs/ace/processing_exception',
                                    class: e.class, backtrace: e.backtrace).to_h
          }
        }
        return [500, process_error.to_json]
      else
        result = {
          certname: certname,
          status: run_result.delete('status'),
          result: run_result
        }
        [200, result.to_json]
      end
    end
  end
end
