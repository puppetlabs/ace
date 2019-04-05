# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'ace/client/catalog'
require 'ace/config'

RSpec.describe ACE::Client::Catalog do
  describe '#new' do
    context 'when a valid config is passed' do
      let(:config) { ACE::Config.new({}) }

      it { expect { described_class.new(config) }.not_to raise_error }
    end

    context 'when an invalid config is passed' do
      let(:config) { {} }

      it { expect { described_class.new(config) }.to raise_error ACE::Error, /`config` must be an ACE::Config/ }
    end
  end

  def stub_catalog_request(**options)
    stub_request(:post, 'https://foo:1234/puppet/v4/catalog')
      .to_return(options)
  end

  describe '#retrieve' do
    let(:config) { ACE::Config.new(config_data) }
    let(:instance) { described_class.new(config) }
    let(:config_data) do
      {
        'ssl-cert' => 'spec/fixtures/ssl/cert.pem',
        'ssl-key' => 'spec/fixtures/ssl/key.pem',
        'ssl-ca-cert' => 'spec/fixtures/ssl/ca.pem',
        'ssl-ca-crls' => 'spec/fixtures/ssl/crl.pem',
        'puppet-server-uri' => 'https://foo:1234'
      }
    end
    let(:request) do
      {
        certname: 'foo.example.com',
        environment: 'development',
        facts: {},
        trusted: {},
        transaction_uuid: '<transaction_id>',
        job_id: '<job_id>'
      }
    end
    let(:request_body) do
      {
        "certname": 'foo.example.com',
        "persistence": {
          "facts": true, "catalog": true
        },
        "environment": 'development',
        "facts": {
          "values": {}
        },
        "trusted_facts": {
          "values": {}
        },
        "transaction_uuid": '<transaction_id>',
        "job_id": '<job_id>',
        "options": {
          "prefer_requested_environment": true,
          "capture_logs": false
        }
      }
    end

    it 'config should be valid' do
      expect { config.validate }.not_to raise_error
    end

    context 'when a valid request is made' do
      it 'calls the v4 catalog endpoint' do
        stub_catalog_request(status: 200, body: "{}")

        instance.retrieve(request[:certname],
                          request[:environment],
                          request[:facts],
                          request[:trusted],
                          request[:transaction_uuid],
                          request[:job_id])

        expect(a_request(:post, 'https://foo:1234/puppet/v4/catalog')
              .with(body: request_body.to_json)).to have_been_made.once
      end
    end

    context 'when a request is not a success' do
      let(:error_body) { "{ error: 'wibble' }" }

      it 'throws an ACE::Error with the response body' do
        stub_catalog_request(status: 500, body: error_body)

        expect {
          instance.retrieve(request[:certname],
                            request[:environment],
                            request[:facts],
                            request[:trusted],
                            request[:transaction_uuid],
                            request[:job_id])
        }.to raise_error { |error|
          expect(error).to be_a ACE::Error
          expect(error.kind).to eq 'puppetlabs/ace/client_failure'
          expect(error.details).to eq(body: error_body)
        }

        expect(a_request(:post, 'https://foo:1234/puppet/v4/catalog')
              .with(body: request_body.to_json)).to have_been_made.once
      end
    end

    context 'when the HTTP request throws an exception' do
      it 'catches and throw an ACE::Error' do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ETIMEDOUT, 'Failed to open TCP connection to foo:1234')

        expect {
          instance.retrieve(request[:certname],
                            request[:environment],
                            request[:facts],
                            request[:trusted],
                            request[:transaction_uuid],
                            request[:job_id])
        }.to raise_error { |error|
          expect(error).to be_a ACE::Error
          expect(error.kind).to eq 'puppetlabs/ace/client_exception'
        }
      end
    end
  end
end
