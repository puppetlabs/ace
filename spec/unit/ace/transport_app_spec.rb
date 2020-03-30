# frozen_string_literal: true

require 'spec_helper'
require 'ace/config'
require 'ace/configurer'
require 'ace/error'
require 'ace/transport_app'
require 'rack/test'
require 'puppet/resource_api/transport'

RSpec.describe ACE::TransportApp do
  include Rack::Test::Methods

  def app
    ACE::TransportApp.new(ACE::Config.new(base_config))
  end

  let(:base_config) do
    {
      "puppet-server-uri" => "https://localhost:9999",
      "cache-dir" => "/tmp/base_config"
    }
  end
  let(:executor) { instance_double(Bolt::Executor, 'executor') }
  let(:file_cache) { instance_double(BoltServer::FileCache, 'file_cache') }
  let(:task_response) { instance_double(Bolt::ResultSet, 'task_response') }
  let(:plugins) { instance_double(ACE::PluginCache, 'plugin_cache') }
  let(:response) { instance_double(Bolt::Result, 'response') }
  let(:configurer) { instance_double(ACE::Configurer, 'configurer') }

  let(:status) do
    {
      node: "fw.example.net",
      status: "success",
      value: {
        "output" => "Hello!"
      }
    }
  end
  let(:body) do
    {
      'task': echo_task,
      'target': connection_info,
      'parameters': { "message": "Hello!" }
    }
  end
  let(:execute_catalog_body) do
    {
      "target": {
        "remote-transport": "panos",
        "host": "fw.example.net",
        "user": "foo",
        "password": "wibble"
      },
      "compiler": {
        "certname": certname,
        "environment": "development",
        "enforce_environment": false,
        "transaction_uuid": "<uuid string>",
        "job_id": "<id string>"
      }
    }
  end
  let(:echo_task) do
    {
      'name': 'sample::echo',
      'metadata': {
        'description': 'Echo a message',
        'parameters': { 'message': 'Default message' }
      },
      files: [{
        filename: "echo.sh",
        sha256: "foo",
        uri: {}
      }]
    }
  end
  let(:connection_info) do
    {
      'remote-transport': 'panos',
      'address': 'hostname',
      'username': 'user',
      'password': 'password'
    }
  end

  before do
    allow(Bolt::Executor).to receive(:new).with(0).and_return(executor)
    allow(BoltServer::FileCache).to receive(:new).and_return(file_cache)
    allow(ACE::PluginCache).to receive(:new).and_return(plugins)
    allow(file_cache).to receive(:setup)
    allow(plugins).to receive(:setup).and_return(plugins)
    allow(ACE::PuppetUtil).to receive(:init_global_settings)
  end

  describe '/' do
    it 'responds ok' do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
    end
  end

  describe '#trusted_facts' do
    it 'correctly parses a valid fqdn' do
      expect(described_class.trusted_facts('foo.domain.com')).to eq(authenticated: "remote",
                                                                    certname: "foo.domain.com",
                                                                    domain: "domain.com",
                                                                    extensions: {},
                                                                    hostname: "foo")
    end

    it 'correctly returns when cert does not contain a dot' do
      expect(described_class.trusted_facts('foodomaincom')).to eq(authenticated: "remote",
                                                                  certname: "foodomaincom",
                                                                  extensions: {},
                                                                  hostname: "foodomaincom")
    end
  end

  ################
  # Tasks Endpoint
  ################
  describe '/run_task' do
    before do
      allow(ACE::ForkUtil).to receive(:isolate).and_yield

      allow(executor).to receive(:run_task).with(
        match_array(instance_of(Bolt::Target)),
        kind_of(Bolt::Task),
        "message" => "Hello!"
      ).and_return(task_response)

      allow(task_response).to receive(:first).and_return(response)
      allow(response).to receive(:status_hash).and_return(status)
    end

    it 'throws an ace/schema_error if the request is invalid' do
      post '/run_task', JSON.generate({}), 'CONTENT_TYPE' => 'text/json'

      expect(last_response.body).to match(%r{puppetlabs\/ace\/schema-error})
      expect(last_response.status).to eq(400)
    end

    it 'throws an ace/request_exception if the JSON is invalid' do
      post '/run_task', 'not json', 'CONTENT_TYPE' => 'text/json'

      expect(last_response.body).to match(%r{puppetlabs\/ace\/request_exception})
      expect(last_response.status).to eq(400)
    end

    it 'throws an ace/request_exception if the request is invalid JSON' do
      post '/run_task', '{ foo }', 'CONTENT_TYPE' => 'text/json'

      expect(last_response.body).to match(%r{puppetlabs\/ace\/request_exception})
      expect(last_response.status).to eq(400)
    end

    context 'when Bolt::Target throws' do
      before do
        allow(Bolt::Target).to receive(:new).and_raise Bolt::ParseError
      end

      it 'will be caught and handled by ace/execution_exception' do
        post '/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'

        expect(last_response.body).to match(%r{puppetlabs\/ace\/execution_exception})
        expect(last_response.status).to eq(500)
      end
    end

    context 'when Bolt::Inventory throws' do
      before do
        allow(Bolt::Inventory).to receive(:empty).and_raise(StandardError.new('yeah right'))
      end

      it 'will be caught and handled by ace/processing_exception' do
        post '/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'

        expect(last_response.body).to match(%r{puppetlabs\/ace\/execution_exception})
        expect(last_response.status).to eq(500)
      end
    end

    context 'when the task executes cleanly' do
      it 'returns the output' do
        post '/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'

        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['value']['output']).to eq('Hello!')
      end
    end

    context 'when no remote-transport is specified' do
      let(:connection_info) do
        {
          'address': 'hostname',
          'username': 'user',
          'password': 'password'
        }
      end

      it 'returns the output' do
        post '/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'

        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['value']['output']).to eq('Hello!')
      end
    end

    context 'when the task executed returns a `backtrace`' do
      let(:status) do
        {
          node: "fw.example.net",
          status: "failure",
          value: {
            '_error' => {
              'msg' => 'Failed to open TCP connection to fw.example.net',
              'kind' => 'module/unknown',
              'details' => {
                'class' => 'SocketError',
                'backtrace' => [
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:906:in `rescue in block in connect'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:903:in `block in connect'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/timeout.rb:93:in `block in timeout'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/timeout.rb:103:in `timeout'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:902:in `connect'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:887:in `do_start'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:882:in `start'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:608:in `start'"
                ]
              }
            }
          }
        }
      end

      it 'runs returns the output and removes the error' do
        post '/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'

        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'failure')
        expect(result['value']['_error']).not_to have_key('backtrace')
      end
    end

    context 'when the task executed returns a `stack_trace`' do
      let(:status) do
        {
          node: "fw.example.net",
          status: "failure",
          value: {
            '_error' => {
              'msg' => 'Failed to open TCP connection to fw.example.net',
              'kind' => 'module/unknown',
              'details' => {
                'class' => 'SocketError',
                'stack_trace' => [
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:906:in `rescue in block in connect'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:903:in `block in connect'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/timeout.rb:93:in `block in timeout'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/timeout.rb:103:in `timeout'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:902:in `connect'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:887:in `do_start'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:882:in `start'",
                  "/Users/foo/.rbenv/versions/2.4.1/lib/ruby/2.4.0/net/http.rb:608:in `start'"
                ]
              }
            }
          }
        }
      end

      it 'runs returns the output and removes the error' do
        post '/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'

        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'failure')
        expect(result['value']['_error']).not_to have_key('stack_trace')
      end
    end
  end

  describe '/check' do
    it 'calls the correct method' do
      post '/check', {}, 'CONTENT_TYPE' => 'text/json'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
    end
  end

  ##################
  # Catalog Endpoint
  ##################
  describe '/execute_catalog' do
    let(:certname) { 'fw.example.net' }
    let(:report) {
      OpenStruct.new(time: 'time',
                     environment: 'some_env',
                     status: 'unchanged',
                     metrics: { "resources" => OpenStruct.new("values" => [
                                                                ["metric name", "The Human Readable Metric Name", 666]
                                                              ]) })
    }
    let(:psettings) { { log_level: :wibble } }

    before {
      allow(plugins).to receive(:with_synced_libdir).and_yield
      allow(described_class).to receive(:init_puppet_target)

      allow(Puppet).to receive(:settings).and_return(psettings)

      allow(ACE::Configurer).to receive(:new).and_return(configurer)
      allow(configurer).to receive(:run) { |options| options[:report] = report }
    }

    # rubocop:disable RSpec/MessageSpies
    describe 'success' do
      it 'returns 200 with success' do
        expect(psettings).to receive(:[]=).with(:noop, false)
        expect(psettings).not_to receive(:[]=).with(:log_level, :debug)
        expect(psettings).to receive(:[]=).with(:trace, false)
        expect(psettings).to receive(:[]=).with(:evaltrace, false)

        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect { |b| plugins.with_synced_libdir('development', false, certname, &b) }.to yield_with_no_args

        expect(configurer).to have_received(:run)
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to eq('certname' => certname, 'status' => 'unchanged',
                             "result" => { "environment" => "some_env",
                                           "job_id" => "<id string>",
                                           "metrics" => { "metric name" => 666 },
                                           "time" => "time",
                                           "transaction_uuid" => "<uuid string>" })
      end
    end

    context 'when given flag debug' do
      it 'returns 200 with success' do
        execute_catalog_body[:compiler][:debug] = true

        expect(psettings).to receive(:[]=).with(:noop, false)
        expect(psettings).to receive(:[]=).with(:log_level, :debug)
        expect(psettings).to receive(:[]=).with(:trace, false)
        expect(psettings).to receive(:[]=).with(:evaltrace, false)

        # handle the reset of log_level
        expect(psettings).to receive(:[]=).with(:log_level, :wibble)

        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'

        expect(configurer).to have_received(:run)
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end
    end

    context 'when given flag noop' do
      it 'returns 200 with success' do
        execute_catalog_body[:compiler][:noop] = true

        expect(psettings).to receive(:[]=).with(:noop, true)
        expect(psettings).not_to receive(:[]=).with(:log_level, :debug)
        expect(psettings).to receive(:[]=).with(:trace, false)
        expect(psettings).to receive(:[]=).with(:evaltrace, false)

        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'

        expect(configurer).to have_received(:run)
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end
    end

    context 'when given flag trace' do
      it 'returns 200 with success' do
        execute_catalog_body[:compiler][:trace] = true

        expect(psettings).to receive(:[]=).with(:noop, false)
        expect(psettings).not_to receive(:[]=).with(:log_level, :debug)
        expect(psettings).to receive(:[]=).with(:trace, true)
        expect(psettings).to receive(:[]=).with(:evaltrace, false)

        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'

        expect(configurer).to have_received(:run)
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end
    end

    context 'when given flag evaltrace' do
      it 'returns 200 with success' do
        execute_catalog_body[:compiler][:evaltrace] = true

        expect(psettings).to receive(:[]=).with(:noop, false)
        expect(psettings).not_to receive(:[]=).with(:log_level, :debug)
        expect(psettings).to receive(:[]=).with(:trace, false)
        expect(psettings).to receive(:[]=).with(:evaltrace, true)

        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'

        expect(configurer).to have_received(:run)
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end
    end
    # rubocop:enable RSpec/MessageSpies

    context 'when the schema is invalid' do
      let(:execute_catalog_body) do
        {
          "target": {
            "remote-transport": "panos",
            "host": "fw.example.net",
            "user": "foo",
            "password": "wibble"
          },
          "compiler": {
            "certname": certname,
            "transaction_uuid": "<uuid string>",
            "job_id": "<id string>"
          }
        }
      end

      it 'returns 400 with _error' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect { |b| plugins.with_synced_libdir('development', false, certname, &b) }.to yield_with_no_args
        expect(last_response.status).to eq(400)
        result = JSON.parse(last_response.body)
        expect(result['status']).to eq('failure')
        expect(result['result']['_error']['msg']).to eq('There was an error validating the request body.')
        expect(result['result']['_error']['kind']).to eq('puppetlabs/ace/schema-error')
        expect(result['result']['_error']['details']['schema_error']).to match(
          %r{The property '#/compiler' did not contain a required property of 'environment' in schema}
        )
      end
    end

    context 'when the JSON is badly formatted' do
      let(:bad_json) {
        '{
          "target":{
            "remote-transport":"panos"
            "host":"12345.delivery.puppetlabs.net"
            "user":"admin"
            "password":"admin"
          },
          "compiler":{
            "certname":"12345.delivery.puppetlabs.net"
            "environment":"production"
            "transaction_uuid":"981687ce-520e-11e9-8647-d663bd873d93"
            "job_id":"1"
          }
        }'
      }

      it 'returns 400 with _error' do
        post '/execute_catalog', bad_json, 'CONTENT_TYPE' => 'text/json'
        expect { |b| plugins.with_synced_libdir('development', false, certname, &b) }.to yield_with_no_args
        expect(last_response.status).to eq(400)
        result = JSON.parse(last_response.body)
        expect(result['status']).to eq('failure')
        expect(result['result']['_error']['msg']).to match(/unexpected token at/)
        expect(result['result']['_error']['kind']).to eq('puppetlabs/ace/request_exception')
        expect(result['result']['_error']['details']['class']).to eq('JSON::ParserError')
        expect(result['result']['_error']['details']).to be_key('backtrace')
      end
    end

    context 'when the error is an ACE error' do
      let(:error) { ACE::Error.new("something", "something/darkside") }

      before {
        allow(ACE::Configurer).to receive(:new).and_raise(error)
      }

      it 'returns 400 with _error' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect { |b| plugins.with_synced_libdir('development', false, certname, &b) }.to yield_with_no_args
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response.status).to eq(400)
        result = JSON.parse(last_response.body)
        expect(result).to eq('certname' => 'fw.example.net', 'status' => 'failure',
                             'result' => { '_error' => { 'msg' => 'something',
                                                         'kind' => 'something/darkside', 'details' => {} } })
      end
    end

    context 'when the error is an unknown error' do
      let(:error) { RuntimeError.new("unknown error") }

      before {
        allow(ACE::Configurer).to receive(:new).and_raise(error)
      }

      it 'returns 500 with _error' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect { |b| plugins.with_synced_libdir('development', false, certname, &b) }.to yield_with_no_args
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response.status).to eq(500)
        result = JSON.parse(last_response.body)
        expect(result['status']).to eq('failure')
        expect(result['result']['_error']['msg']).to eq('unknown error')
        expect(result['result']['_error']['kind']).to eq('puppetlabs/ace/processing_exception')
        expect(result['result']['_error']['details']['class']).to eq('RuntimeError')
        expect(result['result']['_error']['details']).to be_key('backtrace')
      end
    end
  end

  ##################
  # init_puppet_target function
  ##################
  describe 'init_puppet_target' do
    describe 'success with transport style connection info' do
      device_raw = '{
            "target": {
                "remote-transport":"panos",
                "host":"fw.example.net",
                "user":"foo",
                "password":"wibble"
            },
            "compiler": {
                "certname":"fw.example.net",
                "environment":"development",
                "transaction_uuid":"<uuid string>",
                "job_id":"<id string>"
            }
        }'
      device_json = JSON.parse(device_raw)
      test_hash = Hash[device_json['target'].map { |(k, v)| [k.to_sym, v] }]
      test_hash.delete(:"remote-transport")
      # Our actual function inits a device, mocking this out with a simple return string for the purposes of test
      it 'returns correct device' do
        allow(Puppet::Util::NetworkDevice).to receive(:init) do |params|
          expect(params[:provider]).to eq(device_json['target']['remote-transport'])
          expect(params[:url]).to eq(test_hash)
          expect(params[:name]).to eq(device_json['compiler']['certname'])
          expect(params[:options]).to eql({})
          'panos_device'
        end

        expect(described_class.init_puppet_target(device_json['compiler']['certname'],
                                                  device_json['target']['remote-transport'],
                                                  device_json['target'])).to match(/(panos_device)/)
      end
    end

    describe 'success with legacy style uri' do
      device_raw = '{
          "target":{
            "remote-transport":"f5",
            "uri":"https://foo:wibble@f5.example.net/"
          },
          "compiler":{
            "certname":"f5.example.net",
            "environment":"development",
            "transaction_uuid":"<uuid string>",
            "job_id":"<id string>"
          }
        }'
      device_json = JSON.parse(device_raw)
      # Our actual function inits a device, mocking this out with a simple return string for the purposes of test
      it 'returns correct device' do
        allow(Puppet::Util::NetworkDevice).to receive(:init) do |params|
          expect(params[:provider]).to eq(device_json['target']['remote-transport'])
          expect(params[:url]).to eq(device_json['target']['uri'])
          expect(params[:name]).to eq(device_json['compiler']['certname'])
          expect(params[:options]).to eql({})
          'f5_device'
        end

        expect(described_class.init_puppet_target(device_json['compiler']['certname'],
                                                  device_json['target']['remote-transport'],
                                                  device_json['target'])).to match(/(f5_device)/)
      end
    end

    describe 'success with transport connection info' do
      device_raw = '{
            "target": {
                "remote-transport":"panos",
                "host":"fw.example.net",
                "user":"foo",
                "password":"wibble"
            },
            "compiler": {
                "certname":"fw.example.net",
                "environment":"development",
                "transaction_uuid":"<uuid string>",
                "job_id":"<id string>"
            }
        }'
      device_json = JSON.parse(device_raw)
      test_hash = Hash[device_json['target'].map { |(k, v)| [k.to_sym, v] }]
      type = test_hash[:"remote-transport"]
      test_hash.delete(:"remote-transport")
      it 'returns correct transport' do
        allow(Puppet::ResourceApi::Transport).to receive(:connect)
          .with(type, test_hash).and_return(test_hash)
        allow(Puppet::ResourceApi::Transport).to receive(:inject_device)
          .with(type, test_hash).and_return('panos_device')
        expect(described_class.init_puppet_target(device_json['compiler']['certname'],
                                                  device_json['target']['remote-transport'],
                                                  device_json['target'])).to match(/(panos_device)/)
      end
    end

    describe 'raise error when transport not registered' do
      device_raw = '{
            "target": {
                "remote-transport":"panos",
                "host":"fw.example.net",
                "user":"foo",
                "password":"wibble"
            },
            "compiler": {
                "certname":"fw.example.net",
                "environment":"development",
                "transaction_uuid":"<uuid string>",
                "job_id":"<id string>"
            }
        }'
      device_json = JSON.parse(device_raw)
      test_hash = Hash[device_json['target'].map { |(k, v)| [k.to_sym, v] }]
      type = test_hash[:"remote-transport"]
      test_hash.delete(:"remote-transport")

      it 'raises the provided exception' do
        allow(Puppet::ResourceApi::Transport).to receive(:connect)
          .with(type, test_hash).and_raise("Transport for `#{type}` not registered with")
        expect {
          described_class.init_puppet_target(device_json['compiler']['certname'],
                                             device_json['target']['remote-transport'],
                                             device_json['target'])
        } .to raise_error "Transport for `#{type}` not registered with"
      end
    end

    # rubocop:disable RSpec/MessageSpies

    describe 'raise error when invalid uri supplied' do
      device_raw = '{
          "target":{
            "remote-transport":"f5",
            "uri":"£$ %^%£$@ ^£@£"
          },
          "compiler":{
            "certname":"f5.example.net",
            "environment":"development",
            "transaction_uuid":"<uuid string>",
            "job_id":"<id string>"
          }
        }'
      device_json = JSON.parse(device_raw)
      it 'throws error and returns nil device' do
        expect(Puppet::Util::NetworkDevice).not_to receive(:init)

        expect {
          described_class.init_puppet_target(device_json['compiler']['certname'],
                                             device_json['target']['remote-transport'],
                                             device_json['target'])
        } .to raise_error ACE::Error, /There was an error parsing the URI of the Puppet target/
      end
    end

    describe 'raise error when json supplied does not contain target' do
      device_raw = '{
          "compiler":{
            "certname":"f5.example.net",
            "environment":"development",
            "transaction_uuid":"<uuid string>",
            "job_id":"<id string>"
          }
        }'
      device_json = JSON.parse(device_raw)
      it 'throws error and returns nil device' do
        expect(Puppet::Util::NetworkDevice).not_to receive(:init)

        expect {
          described_class.init_puppet_target(device_json['compiler']['certname'],
                                             'cisco_ios',
                                             nil)
        } .to raise_error ACE::Error, /There was an error parsing the Puppet target. 'target' not found/
      end
    end

    describe 'raise error when json supplied does not contain compiler certname' do
      device_raw = '{
          "target": {
                "remote-transport":"panos",
                "host":"fw.example.net",
                "user":"foo",
                "password":"wibble"
          },
          "compiler": {
            "environment":"development",
            "transaction_uuid":"<uuid string>",
            "job_id":"<id string>"
          }
        }'
      device_json = JSON.parse(device_raw)
      it 'throws error and returns nil device' do
        expect(Puppet::Util::NetworkDevice).not_to receive(:init)

        expect {
          described_class.init_puppet_target(nil,
                                             device_json['target']['remote-transport'],
                                             device_json['target'])
        } .to raise_error ACE::Error, /There was an error parsing the Puppet compiler details. 'certname' not found/
      end
    end

    describe 'raise error when json supplied does not contain remote-transport' do
      device_raw = '{
          "target":{
            "uri":"https://foo:wibble@f5.example.com"
          },
          "compiler": {
            "certname":"f5.example.net",
            "environment":"development",
            "transaction_uuid":"<uuid string>",
            "job_id":"<id string>"
          }
        }'
      device_json = JSON.parse(device_raw)
      it 'throws error and returns nil device' do
        expect(Puppet::Util::NetworkDevice).not_to receive(:init)

        expect {
          described_class.init_puppet_target(device_json['compiler']['certname'],
                                             nil,
                                             device_json['target'])
        } .to raise_error ACE::Error, /There was an error parsing the Puppet target. 'transport' not found/
      end
    end
    # rubocop:enable RSpec/MessageSpies
  end
end
