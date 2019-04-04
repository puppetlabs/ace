# frozen_string_literal: true

require 'fileutils'
require 'puppet/configurer'
require 'concurrent'
require 'ace/fork_util'

module ACE
  class PluginCache
    attr_reader :config, :cache_dir_mutex, :uri
    def initialize(config)
      @config = config
      @uri = URI.parse(config['puppet-server-uri'])
      @cache_dir_mutex = Concurrent::ReadWriteLock.new
    end

    def setup
      FileUtils.mkdir_p(config['cache-dir'])
      self
    end

    def with_synced_libdir(environment)
      ForkUtil.isolate do
        with_synced_libdir_core(environment)
      end
    end

    def with_synced_libdir_core(environment)
      libdir = sync_core(environment)
      Puppet[:libdir] = libdir
      yield
    ensure
      FileUtils.remove_dir(libdir)
    end

    # the Puppet[:libdir] will point to a tmp location
    # where the contents from the pluginsync dest is copied
    # too.
    def libdir(plugin_dest)
      tmpdir = Dir.mktmpdir(['plugins', plugin_dest])
      cache_dir_mutex.with_write_lock do
        FileUtils.cp_r(File.join(plugin_dest, '.'), tmpdir)
        FileUtils.touch(tmpdir)
      end
      tmpdir
    end

    def environment_dir(environment)
      environment_dir = File.join(config['cache-dir'], environment)
      cache_dir_mutex.with_write_lock do
        FileUtils.mkdir_p(environment_dir)
        FileUtils.touch(environment_dir)
      end
      environment_dir
    end

    def configure_puppet_settings
      Puppet::Util::Log.destinations.clear
      Puppet::Util::Log.newdestination(:console)
      Puppet.settings[:log_level] = 'notice'
      Puppet.settings[:trace] = true
      Puppet.settings[:catalog_terminus] = :rest
      Puppet.settings[:node_terminus] = :rest
      Puppet.settings[:catalog_cache_terminus] = :json
      Puppet.settings[:facts_terminus] = :network_device
    end

    def ssl_context
      @ssl_context ||= Puppet::SSL::SSLProvider.new.create_context(
        cacerts: [OpenSSL::X509::Certificate.new(File.read(config['ssl-ca-cert']))],
        crls: [OpenSSL::X509::CRL.new(File.read(config['ssl-ca-crls']))],
        private_key: OpenSSL::PKey::RSA.new(File.read(config['ssl-key'])),
        client_cert: OpenSSL::X509::Certificate.new(File.read(config['ssl-cert']))
      )
    end

    # @returns the tmp libdir directory which will be where
    # Puppet[:libdir] is referenced too
    def sync_core(environment)
      configure_puppet_settings
      env = Puppet::Node::Environment.remote(environment)
      environments_dir = environment_dir(environment)
      # set up puppet logging
      # , :loaders => Puppet::Pops::Loaders.new(env) will need to be revisited
      Puppet.override(current_environment: env, serverport: uri.port) do
        Puppet[:vardir] = File.join(environments_dir, environment)
        Puppet[:server] = uri.host
        Puppet[:confdir] = File.join(environments_dir, 'conf')
        Puppet[:rundir] = File.join(environments_dir, 'run')
        Puppet[:logdir] = File.join(environments_dir, 'log')
        Puppet[:codedir] = File.join(environments_dir, 'code')
        Puppet[:plugindest] = File.join(environments_dir, 'plugins')
        Puppet.settings.use :main, :agent, :ssl
        pool = Puppet::Network::HTTP::NoCachePool.new
        begin
          Puppet.override(ssl_context: ssl_context, http_pool: pool) do
            Puppet::Configurer::PluginHandler.new.download_plugins(env)
          end
        ensure
          pool.close
        end
      end
      libdir(File.join(environments_dir, 'plugins'))
    end
  end
end
