# frozen_string_literal: true

require 'spec_helper'
require 'ace/transport_app'
require 'rack/test'
require 'ace/config'

RSpec.describe ACE::TransportApp do
  include Rack::Test::Methods

  def app
    ACE::TransportApp.new(ACE::Config.new(base_config))
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

  ##################
  # Catalog Endpoint
  ##################
  describe '/execute_catalog' do
    describe 'success' do
      it 'returns 200 with `report_generated` status' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result['certname']).to eq('localhost')
        expect(result['status']).to eq('report_generated')
      end
    end
  end
end
