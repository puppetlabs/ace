# frozen_string_literal: true

require 'spec_helper'
require 'ace/config'
require 'ace/transport_app'
require 'faraday'
require 'openssl'
require 'rack/test'

module Acceptance
  class SUT
    attr_reader :app

    def self.app
      base_config = {
        "ssl-cert" => "spec/volumes/puppet/ssl/certs/aceserver.pem",
        "ssl-key" => "spec/volumes/puppet/ssl/private_keys/aceserver.pem",
        "ssl-ca-cert" => "spec/volumes/puppet/ssl/certs/ca.pem",
        "ssl-ca-crls" => "spec/volumes/puppet/ssl/ca/ca_crl.pem",
        "puppet-server-uri" => "https://0.0.0.0:8140",
        "loglevel" => "debug",
        "tmp-dir" => "tmp/",
        "cache-dir" => "tmp/cache",
        "host" => "0.0.0.0"
      }
      config = ACE::Config.new(base_config)
      config.make_compatible
      config.validate

      @app ||= ACE::TransportApp.new(config)
    end
  end
end

RSpec.describe ACE::TransportApp do
  include Rack::Test::Methods
  include Acceptance

  before do
    # see: https://github.com/bblimke/webmock#connecting-on-nethttpstart
    WebMock.allow_net_connect!(net_http_connect_on_start: true)
  end

  after do
    WebMock.disable_net_connect!
  end

  def app
    # Ensure only one instance of the application runs
    Acceptance::SUT.app
  end

  ##################
  # Catalog Endpoint
  ##################
  describe '/execute_catalog' do
    let(:execute_catalog_body) do
      {
        "target": {
          "remote-transport": "spinner"
        },
        "compiler": {
          "certname": "localhost",
          "environment": environment,
          "enforce_environment": enforce_environment,
          "transaction_uuid": "2d931510-d99f-494a-8c67-87feb05e1594",
          "job_id": "1"
        }
      }
    end

    before { post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json' }

    context 'when enforcing a matching environment' do
      let(:environment) { "production" }
      let(:enforce_environment) { true }

      it { expect(last_response.errors).to match(/\A\Z/) }
      it { expect(last_response).to be_ok }
      it { expect(last_response.status).to eq(200) }
      it { expect(JSON.parse(last_response.body)['certname']).to eq('localhost') }
      it { expect(JSON.parse(last_response.body)['status']).to eq('unchanged') }
    end

    context 'when enforcing a non-matching environment' do
      let(:environment) { "something_else" }
      let(:enforce_environment) { true }

      it { expect(last_response.errors).to match(/\A\Z/) }
      it { expect(last_response).to be_ok }
      it { expect(last_response.status).to eq(200) }
      it { expect(JSON.parse(last_response.body)['certname']).to eq('localhost') }
      it { expect(JSON.parse(last_response.body)['status']).to eq('failed') }
    end

    context 'when not enforcing a environment' do
      let(:environment) { "" }
      let(:enforce_environment) { false }

      it { expect(last_response.errors).to match(/\A\Z/) }
      it { expect(last_response).to be_ok }
      it { expect(last_response.status).to eq(200) }
      it { expect(JSON.parse(last_response.body)['certname']).to eq('localhost') }
      it { expect(JSON.parse(last_response.body)['status']).to eq('unchanged') }
    end

    context 'when enforcing an environment and not providing an environment' do
      let(:environment) { "" }
      let(:enforce_environment) { true }

      it { expect(last_response.errors).to match(/\A\Z/) }
      it { expect(last_response).not_to be_ok }
      it { expect(last_response.status).to eq(400) }
      it { expect(JSON.parse(last_response.body)['status']).to eq('failure') }
      it { expect(JSON.parse(last_response.body)['result']['_error']['kind']).to eq('puppetlabs/ace/execute_catalog') }

      it {
        expect(JSON.parse(last_response.body)['result']['_error']['msg']).to eq(
          'You MUST provide an `environment` when `enforce_environment` is set to true'
        )
      }
    end
  end

  ##################
  # Task Endpoint
  ##################
  transports = ['spinner', 'spinner_transport']
  transports.each do |transport|
    describe "/run_task for #{transport}" do
      let(:task_metadata) {
        Faraday.new(
          url: 'https://0.0.0.0:8140/puppet/v3/tasks/test_device/device_spin?environment=production',
          ssl: {
            client_cert: OpenSSL::X509::Certificate.new(File.read('spec/volumes/puppet/ssl/certs/aceserver.pem')),
            client_key: OpenSSL::PKey::RSA.new(File.read('spec/volumes/puppet/ssl/private_keys/aceserver.pem')),
            ca_file: 'spec/volumes/puppet/ssl/certs/ca.pem'
          }
        )
      }

      let(:task_body) do
        response = task_metadata.get
        JSON.parse(response.body)
      end

      let(:run_task_body) do
        {
          "task": task_body,
          "target": {
            "remote-transport": transport
          },
          "parameters": {
            "cpu_time": 1,
            "wait_time": 1
          }
        }
      end

      describe 'success' do
        it 'returns 200 with `success` status' do
          post '/run_task', JSON.generate(run_task_body), 'CONTENT_TYPE' => 'text/json'
          expect(last_response.errors).to match(/\A\Z/)
          expect(last_response).to be_ok
          expect(last_response.status).to eq(200)
          result = JSON.parse(last_response.body)
          expect(result['status']).to eq('success')
        end
      end
    end
  end
end
