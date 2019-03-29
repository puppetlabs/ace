# frozen_string_literal: true

require 'spec_helper'
require 'ace/config'

RSpec.describe ACE::Config do
  def build_config(config_file, from_env = false)
    config = ACE::Config.new
    config.load_file_config(config_file)
    config.load_env_config if from_env
    config.validate
    config
  end

  let(:configdir) { File.join(__dir__, '../../', 'fixtures', 'api_server_configs') }
  let(:globalconfig) { File.join(configdir, 'global-ace-server.conf') }
  let(:requiredconfig) { File.join(configdir, 'required-ace-server.conf') }
  let(:base_config) { Hocon.load(requiredconfig)['ace-server'] }

  let(:complete_config_keys) {
    ['host', 'port', 'ssl-cert', 'ssl-key', 'ssl-ca-cert',
     'ssl-cipher-suites', 'loglevel', 'logfile', 'whitelist',
     'concurrency', 'cache-dir', 'file-server-conn-timeout',
     'file-server-uri', 'ssl-ca-crls']
  }

  let(:complete_env_keys) {
    ['ssl-cert', 'ssl-key', 'ssl-ca-cert', 'loglevel',
     'concurrency', 'file-server-conn-timeout',
     'file-server-uri', 'ssl-ca-crls']
  }

  let(:complete_ssl_keys) {
    ['ssl-cert', 'ssl-key', 'ssl-ca-cert', 'ssl-ca-crls']
  }

  let(:complete_required_keys) {
    ['ssl-cert', 'ssl-key', 'ssl-ca-cert', 'ssl-ca-crls', 'file-server-uri', 'cache-dir']
  }

  let(:complete_defaults) {
    { 'host' => '127.0.0.1',
      'loglevel' => 'notice',
      'ssl-cipher-suites' => ['ECDHE-ECDSA-AES256-GCM-SHA384',
                              'ECDHE-RSA-AES256-GCM-SHA384',
                              'ECDHE-ECDSA-CHACHA20-POLY1305',
                              'ECDHE-RSA-CHACHA20-POLY1305',
                              'ECDHE-ECDSA-AES128-GCM-SHA256',
                              'ECDHE-RSA-AES128-GCM-SHA256',
                              'ECDHE-ECDSA-AES256-SHA384',
                              'ECDHE-RSA-AES256-SHA384',
                              'ECDHE-ECDSA-AES128-SHA256',
                              'ECDHE-RSA-AES128-SHA256'],
      'port' => 44633,
      'concurrency' => 10,
      'cache-dir' => "/opt/puppetlabs/server/data/ace-server/cache",
      'file-server-conn-timeout' => 120 }
  }

  it 'returns config_keys as an array' do
    expect(described_class.new.config_keys).to be_a(Array)
  end

  # These tests provide us with insight should the values from the Bolt controlled
  # base class change.
  it 'config_keys contains the expected base keys' do
    expect(described_class.new.config_keys).to eq(complete_config_keys)
  end

  it 'returns env_keys as an array' do
    expect(described_class.new.env_keys).to be_a(Array)
  end

  it 'env_keys contains the expected base keys' do
    expect(described_class.new.env_keys).to eq(complete_env_keys)
  end

  it 'returns int_keys as an array' do
    expect(described_class.new.int_keys).to be_a(Array)
  end

  it 'returns defaults as a hash' do
    expect(described_class.new.defaults).to be_a(Hash)
  end

  it 'defaults contains the expected base defaults' do
    expect(described_class.new.defaults).to eq(complete_defaults)
  end

  it 'returns required_keys as an array' do
    expect(described_class.new.required_keys).to be_a(Array)
  end

  it 'required_keys contains the expected base keys' do
    expect(described_class.new.required_keys).to eq(complete_required_keys)
  end

  context 'with configuation parameters set in environment variables' do
    def transform_key(key)
      "ACE_#{key.tr('-', '_').upcase}"
    end

    before(:context) do # ENV is global state needed to be manually cleaned # rubocop:disable RSpec/BeforeAfterAll
      empty = described_class.new
      empty.env_keys.each do |key|
        transformed_key = transform_key(key)
        ENV[transformed_key] = if empty.int_keys.include?(key)
                                 '23'
                               else
                                 __FILE__
                               end
      end
    end

    let(:fake_env_config) { __FILE__ }
    let(:config) { build_config(globalconfig, true) }

    after(:context) do # ENV is global state needed to be manually cleaned # rubocop:disable RSpec/BeforeAfterAll
      described_class.new.env_keys.each do |key|
        ENV.delete(transform_key(key))
      end
    end

    it 'reads ssl-cert ' do
      expect(config['ssl-cert']).to eq(fake_env_config)
    end

    it 'reads ssl-key' do
      expect(config['ssl-key']).to eq(fake_env_config)
    end

    it 'reads ssl-ca-cert' do
      expect(config['ssl-ca-cert']).to eq(fake_env_config)
    end

    it 'reads loglevel' do
      expect(config['loglevel']).to eq(fake_env_config)
    end

    it 'reads concurrency' do
      expect(config['concurrency']).to eq(23)
    end

    it 'reads file-server-conn-timeout' do
      expect(config['file-server-conn-timeout']).to eq(23)
    end

    it 'reads file-server-uri' do
      expect(config['file-server-uri']).to eq(fake_env_config)
    end
  end

  it "errors when concurrency is not an integer" do
    expect {
      described_class.new(base_config.merge('concurrency' => '10')).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'concurrency' must be a positive integer")
  end

  it "errors when concurrency is zero" do
    expect {
      described_class.new(base_config.merge('concurrency' => 0)).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'concurrency' must be a positive integer")
  end

  it "errors when concurrency is negative" do
    expect {
      described_class.new(base_config.merge('concurrency' => -1)).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'concurrency' must be a positive integer")
  end

  it "errors when file-server-conn-timeout is not an integer" do
    expect {
      described_class.new(base_config.merge('file-server-conn-timeout' => '120')).validate
    }.to raise_error(Bolt::ValidationError, "Configured 'file-server-conn-timeout' must be a positive integer")
  end
end
