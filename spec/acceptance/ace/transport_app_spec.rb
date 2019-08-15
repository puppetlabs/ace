# frozen_string_literal: true

require 'spec_helper'
require 'ace/transport_app'
require 'rack/test'
require 'ace/config'
require 'faraday'
require 'openssl'

RSpec.describe ACE::TransportApp do
  include Rack::Test::Methods

  before do
    # see: https://github.com/bblimke/webmock#connecting-on-nethttpstart
    WebMock.allow_net_connect!(net_http_connect_on_start: true)
  end

  after do
    WebMock.disable_net_connect!
  end

  def app
    config = ACE::Config.new(base_config)
    config.make_compatible
    config.validate

    ACE::TransportApp.new(config)
  end

  let(:base_config) do
    {
      "ssl-cert" => "spec/volumes/puppet/ssl/certs/aceserver.pem",
      "ssl-key" => "spec/volumes/puppet/ssl/private_keys/aceserver.pem",
      "ssl-ca-cert" => "spec/volumes/puppet/ssl/certs/ca.pem",
      "ssl-ca-crls" => "spec/volumes/puppet/ssl/ca/ca_crl.pem",
      "puppet-server-uri" => "https://0.0.0.0:8140",
      "loglevel" => "debug",
      "cache-dir" => "./tmp/",
      "host" => "0.0.0.0"
    }
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
          "environment": "production",
          "transaction_uuid": "2d931510-d99f-494a-8c67-87feb05e1594",
          "job_id": "1"
        }
      }
    end

    describe 'success' do
      it 'returns 200 with `unchanged` status' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result['certname']).to eq('localhost')
        expect(result['status']).to eq('unchanged')
      end
    end
  end

  ##################
  # Task Endpoint
  ##################
  describe '/run_task' do
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
          "remote-transport": "spinner"
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
