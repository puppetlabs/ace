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
      "puppet-server-uri" => "https://localhost:8140",
      "cache-dir" => "tmp/"
    }
  end
  
  let(:execute_catalog_body) do
    {
      "target": {
        "remote-transport": "panos",
        host: certname,
        user: "admin",
        password: "admin",
        ssl: false
      },
      "compiler": {
        "certname": certname,
        "environment": "production",
        "transaction_uuid": Random.new_seed.to_s,
        "job_id": Random.new_seed.to_s
      }
    }
  end

  ##################
  # Catalog Endpoint
  ##################
  describe '/execute_catalog' do

    describe 'success' do
      let(:certname) { 'vvtzckq3vzx995w.delivery.puppetlabs.net' }

      it 'returns 200 with empty body when success' do
        post '/execute_catalog', JSON.generate(execute_catalog_body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response.errors).to match(/\A\Z/)
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to eq({})
      end
    end
  end
end
