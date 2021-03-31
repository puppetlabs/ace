# frozen_string_literal: true

require 'puppet/resource/catalog'
require 'puppet/indirector/rest'

module Puppet
  class Resource
    class Catalog
      class Certless < Puppet::Indirector::REST
        desc "Find certless catalogs over HTTP via REST."


        def find(request)
          persistence = { facts: true, catalog: true}
          opts = {
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
          _, catalog = api.post_catalog4(request.key, persistence, request.environment.name.to_s, opts)
          File.open("/tmp/catalog_#{rand(1000)}", 'w') {|f| f.write("#{catalog.to_data_hash}")}
          catalog
        rescue Puppet::HTTP::ResponseError => e
          if e.response.code == 404
            return nil unless request.options[:fail_on_404]

            _, body = parse_response(e.response)
            msg = _("Find %{uri} resulted in 404 with the message: %{body}") % { uri: elide(e.response.url.path, 100), body: body }
            raise Puppet::Error, msg
          else
            raise convert_to_http_error(e.response)
          end
        end
      end
    end
  end
end

# module Puppet
#   class Resource
#     class Catalog
#       class Certless < Puppet::Indirector::REST
#         desc "Find certless catalogs over HTTP via REST."

#         # Override the REST indirector headers for the certless
#         # catalog indirector as the `puppet/pson` header throws of the
#         # request body and wraps it in a "value":{<request>} which
#         # causes a validation error on the v4/catalog endpoint
#         def headers
#           common_headers = {
#             "Content-Type" => 'text/json',
#             "Accept" => 'application/json',
#             Puppet::Network::HTTP::HEADER_PUPPET_VERSION => Puppet.version
#           }

#           add_accept_encoding(common_headers)
#         end

#         def find(request)
#           uri = "/puppet/v4/catalog"

#           body = {
#             "certname": request.key,
#             "persistence": {
#               "facts": true, "catalog": true
#             },
#             "environment": request.environment.name.to_s,
#             "facts": {
#               "values": request.options[:transport_facts]
#             },
#             "trusted_facts": {
#               "values": request.options[:trusted_facts]
#             },
#             "transaction_uuid": request.options[:transaction_uuid],
#             "job_id": request.options[:job_id],
#             "options": {
#               "prefer_requested_environment": false,
#               "capture_logs": false
#             }
#           }
#           require 'pry'; binding.pry
#           response = do_request(request) do |req|
#             http_post(req, uri, body.to_json, headers)
#           end

#           if is_http_200?(response)
#             content_type, body = parse_response(response)
#             # the response from the `v4/catalog` endpoint is in the format of
#             # {"catalog": {}} whereas the configurer expects it to be a
#             # flatter structurer, so passing it the catalog contents from the body
#             # is suited as the API is unlikely to change for
#             # this release
#             result = deserialize_find(content_type, JSON.parse(body)['catalog'].to_json)
#             result.name = request.key if result.respond_to?(:name=)
#             result

#           elsif is_http_404?(response)
#             return nil unless request.options[:fail_on_404]

#             # 404 can get special treatment as the indirector API can not produce a meaningful
#             # reason to why something is not found - it may not be the thing the user is
#             # expecting to find that is missing, but something else (like the environment).
#             # While this way of handling the issue is not perfect, there is at least an error
#             # that makes a user aware of the reason for the failure.
#             #
#             _, body = parse_response(response)
#             msg = format(_("Find %<uri>s resulted in 404 with the message: %<body>s"),
#                          uri: elide(uri, 100),
#                          body: body)
#             raise Puppet::Error, msg
#           end
#         end
#       end
#     end
#   end
# end
