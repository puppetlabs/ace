# frozen_string_literal: true

require 'openssl'

module ACE
  class PuppetUtil
    def self.init_global_settings(ca_cert_path, ca_crls_path, private_key_path, client_cert_path, cachedir, uri)
      Puppet::Util::Log.destinations.clear
      Puppet::Util::Log.newdestination(:console)
      Puppet.settings[:log_level] = 'notice'
      Puppet.settings[:trace] = true
      Puppet.settings[:catalog_terminus] = :certless
      Puppet.settings[:node_terminus] = :memory
      Puppet.settings[:catalog_cache_terminus] = :json
      Puppet.settings[:facts_terminus] = :network_device
      # the following settings are just to make base_context
      # happy, these will not be the final values,
      # as per request settings will be set later on
      # to satisfy multi-environments
      Puppet.settings[:vardir] = cachedir
      Puppet.settings[:confdir] = File.join(cachedir, 'conf')
      Puppet.settings[:rundir] = File.join(cachedir, 'run')
      Puppet.settings[:logdir] = File.join(cachedir, 'log')
      Puppet.settings[:codedir] = File.join(cachedir, 'code')
      Puppet.settings[:plugindest] = File.join(cachedir, 'plugins')
      Puppet.push_context(Puppet.base_context(Puppet.settings), "Puppet Initialization")
      # ssl_context will be a persistent context
      cert_provider = Puppet::X509::CertProvider.new(
        capath: ca_cert_path,
        crlpath: ca_crls_path
      )
      ssl_context = Puppet::SSL::SSLProvider.new.create_context(
        cacerts: cert_provider.load_cacerts(required: true),
        crls: cert_provider.load_crls(required: true),
        private_key: OpenSSL::PKey::RSA.new(File.read(private_key_path, encoding: 'utf-8')),
        client_cert: OpenSSL::X509::Certificate.new(File.read(client_cert_path, encoding: 'utf-8'))
      )
      Puppet.push_context({
                            ssl_context: ssl_context,
                            server: uri.host,
                            serverport: uri.port
                          }, "PuppetServer connection information to be used")
      Puppet.settings.use :main, :agent, :ssl
      Puppet::Transaction::Report.indirection.terminus_class = :rest
    end

    def self.isolated_puppet_settings(certname, environment)
      Puppet.settings[:certname] = certname
      Puppet.settings[:environment] = environment
      env = Puppet::Node::Environment.remote(environment)
      Puppet.push_context({
                            configured_environment: environment,
                            loaders: Puppet::Pops::Loaders.new(env)
                          }, "Isolated settings to be used")
    end
  end
end
