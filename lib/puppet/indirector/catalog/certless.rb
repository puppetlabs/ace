# frozen_string_literal: true

require 'puppet/resource/catalog'
require 'puppet/indirector/rest'

module Puppet
  class Resource
    class Catalog
      class Certless < Puppet::Indirector::REST
        desc "Find certless catalogs over HTTP via REST."

        def find(request)
          certname = request.key
          payload = {
            persistence: { facts: true, catalog: true },
            environment: request.environment.name.to_s,
            facts: request.options[:transport_facts],
            trusted_facts: request.options[:trusted_facts],
            transaction_uuid: request.options[:transaction_uuid],
            job_id: request.options[:job_id],
            options: {
              prefer_requested_environment: false,
              capture_logs: false
            }
          }
          session = Puppet.lookup(:http_session)
          api = session.route_to(:puppet)
          _, catalog, = api.post_catalog4(certname, **payload)
          catalog
        rescue Puppet::HTTP::ResponseError => e
          if e.response.code == 404
            return nil unless request.options[:fail_on_404]

            _, body = parse_response(e.response)
            msg = "Find resulted in 404 with the message: #{body}"
            raise Puppet::Error, msg
          else
            raise convert_to_http_error(e.response)
          end
        end
      end
    end
  end
end
