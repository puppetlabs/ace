# frozen_string_literal: true

require 'net/http'
require 'ace/error'

module ACE
  module Client
    class Catalog
      def initialize(config)
        unless config.is_a? ACE::Config
          raise ACE::Error.new('`config` must be an ACE::Config',
                               'puppetlabs/ace/invalid_param')
        end
        @config = config
      end

      def retrieve(certname, environment, facts, trusted, transaction_uuid, job_id)
        raise ACE::Error.new('`facts` must be a Hash', 'puppetlabs/ace/invalid_param') unless facts.is_a? Hash
        raise ACE::Error.new('`trusted` must be a Hash', 'puppetlabs/ace/invalid_param') unless trusted.is_a? Hash

        uri = URI::HTTP.build(path: '/puppet/v4/catalog')

        input_data = {
          "certname": certname,
          "persistence": {
            "facts": true, "catalog": true
          },
          "environment": environment,
          "facts": {
            "values": facts
          },
          "trusted_facts": {
            "values": trusted
          },
          "transaction_uuid": transaction_uuid,
          "job_id": job_id,
          "options": {
            "prefer_requested_environment": true,
            "capture_logs": false
          }
        }

        header = { 'Content-Type': 'text/json' }
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = input_data.to_json

        begin
          res = client.request(request)
        rescue StandardError => e
          raise ACE::Error.new(e.message,
                               'puppetlabs/ace/client_exception',
                               class: e.class, backtrace: e.backtrace)
        end
        unless res.is_a?(Net::HTTPSuccess)
          raise ACE::Error.new(res.message,
                               'puppetlabs/ace/client_failure',
                               body: res.body)
        end
        res
      end

      private

      def client
        @client ||= begin
                        uri = URI(@config['puppet-server-uri'])
                        Net::HTTP.start(uri.host, uri.port,
                                        use_ssl: true,
                                        ssl_version: :TLSv1_2,
                                        ca_file: @config['ssl-ca-cert'],
                                        cert: OpenSSL::X509::Certificate.new(ssl_cert),
                                        key: OpenSSL::PKey::RSA.new(ssl_key),
                                        verify_mode: OpenSSL::SSL::VERIFY_PEER,
                                        open_timeout: @config['puppet-server-conn-timeout'])
                      end
      end

      def ssl_cert
        @ssl_cert ||= File.read(@config['ssl-cert'])
      end

      def ssl_key
        @ssl_key ||= File.read(@config['ssl-key'])
      end
    end
  end
end
