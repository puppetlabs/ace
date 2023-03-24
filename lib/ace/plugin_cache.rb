# frozen_string_literal: true

require 'fileutils'
require 'ace/puppet_util'
require 'puppet/configurer'
require 'concurrent'
require 'ace/fork_util'

module ACE
  class PluginCache
    attr_reader :cache_dir_mutex, :cache_dir

    PURGE_TIMEOUT = 60 * 60
    PURGE_INTERVAL = 24 * PURGE_TIMEOUT
    PURGE_TTL = 7 * PURGE_INTERVAL

    def initialize(environments_cache_dir,
                   purge_interval: PURGE_INTERVAL,
                   purge_timeout: PURGE_TIMEOUT,
                   purge_ttl: PURGE_TTL,
                   cache_dir_mutex: Concurrent::ReadWriteLock.new,
                   do_purge: true)
      @cache_dir = environments_cache_dir
      @cache_dir_mutex = cache_dir_mutex

      if do_purge
        @purge = Concurrent::TimerTask.new(execution_interval: purge_interval,
                                           timeout_interval: purge_timeout,
                                           run_now: true) { expire(purge_ttl) }
        @purge.execute
      end
    end

    def setup
      FileUtils.mkdir_p(cache_dir)
      self
    end

    def with_synced_libdir(environment, enforce_environment, certname, timeout, &block)
      ForkUtil.isolate(timeout) do
        ACE::PuppetUtil.isolated_puppet_settings(
          certname,
          environment,
          enforce_environment,
          environment_dir(environment)
        )
        with_synced_libdir_core(environment, &block)
      end
    end

    def with_synced_libdir_core(environment)
      libdir = sync_core(environment)
      Puppet.settings[:libdir] = libdir
      $LOAD_PATH << libdir
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
      environment_dir = File.join(cache_dir, environment)
      cache_dir_mutex.with_write_lock do
        FileUtils.mkdir_p(File.join(environment_dir, 'code', 'environments', environment))
        FileUtils.touch(environment_dir)
      end
      environment_dir
    end

    # @returns the tmp libdir directory which will be where
    # Puppet[:libdir] is referenced too
    def sync_core(environment)
      env = Puppet::Node::Environment.remote(environment)
      environments_dir = environment_dir(environment)
      Puppet::Configurer::PluginHandler.new.download_plugins(env)
      libdir(File.join(environments_dir, 'plugins'))
    end

    # the cache_dir will be the `cache-dir` from
    # the ace config, with the appended environments, i.e.
    # /opt/puppetlabs/server/data/ace-server/cache/environments
    # then the directories within this path, which will be
    # the puppet environments will be removed if they have
    # not been modified in the last 7 days
    # when the purge runs (every 24 hours)
    def expire(purge_ttl)
      expired_time = Time.now - purge_ttl
      cache_dir_mutex.with_write_lock do
        Dir.glob(File.join(cache_dir, '*')).select { |f| File.directory?(f) }.each do |dir|
          if File.mtime(dir) < expired_time
            FileUtils.remove_dir(dir)
          end
        end
      end
    end
  end
end
