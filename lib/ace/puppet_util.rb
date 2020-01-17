# frozen_string_literal: true

require 'openssl'

module ACE
  class PuppetUtil
    def self.certificate_revocation
      @certificate_revocation ||= begin
        Puppet.initialize_settings
        result = Puppet[:certificate_revocation]
        Puppet.clear
        result
      end
    end

    def self.init_global_settings(ca_cert_path, ca_crls_path, private_key_path, client_cert_path, cachedir, uri)
      revocation = certificate_revocation

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
      Puppet.settings[:confdir] = File.join(cachedir, 'conf_x')
      Puppet.settings[:rundir] = File.join(cachedir, 'run_x')
      Puppet.settings[:logdir] = File.join(cachedir, 'log_x')
      Puppet.settings[:codedir] = File.join(cachedir, 'code_x')
      Puppet.settings[:plugindest] = File.join(cachedir, 'plugin_x')

      # ssl_context will be a persistent context
      cert_provider = Puppet::X509::CertProvider.new(
        capath: ca_cert_path,
        crlpath: ca_crls_path
      )
      ssl_context = Puppet::SSL::SSLProvider.new.create_context(
        cacerts: cert_provider.load_cacerts(required: true),
        crls: cert_provider.load_crls(required: true),
        private_key: OpenSSL::PKey::RSA.new(File.read(private_key_path, encoding: 'utf-8')),
        client_cert: OpenSSL::X509::Certificate.new(File.read(client_cert_path, encoding: 'utf-8')),
        revocation: revocation
      )
      # Store SSL settings for reuse in isolated process
      @ssl_settings = {
        ssl_context: ssl_context,
        server: uri.host,
        serverport: uri.port
      }
    end

    def self.isolated_puppet_settings(certname, environment, enforce_environment, environment_dir)
      Puppet.settings[:certname] = certname
      Puppet.settings[:environment] = environment
      Puppet.settings[:strict_environment_mode] = enforce_environment

      Puppet.settings[:vardir] = File.join(environment_dir)
      Puppet.settings[:confdir] = File.join(environment_dir, 'conf')
      Puppet.settings[:rundir] = File.join(environment_dir, 'run')
      Puppet.settings[:logdir] = File.join(environment_dir, 'log')
      Puppet.settings[:codedir] = File.join(environment_dir, 'code')
      Puppet.settings[:plugindest] = File.join(environment_dir, 'plugins')

      # establish a base_context. This needs to be the first context on the stack, but must not be created
      # before all settings have been set. For example, this will create a Puppet::Environments::Directories
      # instance copying the :environmentpath setting and never updating this.
      Puppet.push_context(Puppet.base_context(Puppet.settings), "Puppet Initialization")
      Puppet.push_context(@ssl_settings, "PuppetServer connection information to be used")

      # finalise settings initialisation
      Puppet.settings.use :main, :agent, :ssl

      # special override
      Puppet::Transaction::Report.indirection.terminus_class = :rest

      # configure the requested environment, and deploy new loaders
      env = Puppet::Node::Environment.remote(environment)
      Puppet.push_context({
                            configured_environment: environment,
                            loaders: Puppet::Pops::Loaders.new(env)
                          }, "Isolated settings to be used")
    end
  end
end
