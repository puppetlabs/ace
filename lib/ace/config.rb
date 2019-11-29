# frozen_string_literal: true

require 'hocon'
require 'bolt_server/base_config'

module ACE
  class Config < BoltServer::BaseConfig
    attr_reader :data
    def config_keys
      super + %w[concurrency cache-dir puppet-server-conn-timeout puppet-server-uri ssl-ca-crls]
    end

    def env_keys
      super + %w[concurrency puppet-server-conn-timeout puppet-server-uri ssl-ca-crls]
    end

    def ssl_keys
      super + %w[ssl-ca-crls]
    end

    def int_keys
      %w[concurrency puppet-server-conn-timeout]
    end

    def defaults
      super.merge(
        'port' => 44633,
        'status-port' => 44632,
        'concurrency' => 10,
        'cache-dir' => "/opt/puppetlabs/server/data/ace-server/cache",
        'puppet-server-conn-timeout' => 120,
        'file-server-conn-timeout' => 120
      )
    end

    def required_keys
      super + %w[puppet-server-uri cache-dir]
    end

    def service_name
      'ace-server'
    end

    def load_env_config
      env_keys.each do |key|
        transformed_key = "ACE_#{key.tr('-', '_').upcase}"
        next unless ENV.key?(transformed_key)
        @data[key] = if int_keys.include?(key)
                       ENV[transformed_key].to_i
                     else
                       ENV[transformed_key]
                     end
      end
    end

    def validate
      super

      unless natural?(@data['concurrency'])
        raise Bolt::ValidationError, "Configured 'concurrency' must be a positive integer"
      end

      unless natural?(@data['puppet-server-conn-timeout'])
        raise Bolt::ValidationError, "Configured 'puppet-server-conn-timeout' must be a positive integer"
      end
    end

    def make_compatible
      # This function sets values used by Bolt that behave the same in ACE, but have a different meaning
      @data['file-server-uri'] = @data['puppet-server-uri']
      @data['file-server-conn-timeout'] = @data['puppet-server-conn-timeout']
    end
  end
end
