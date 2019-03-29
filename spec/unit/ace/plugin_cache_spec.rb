# frozen_string_literal: true

require 'ace/plugin_cache'
require 'webmock/rspec'
require 'hocon'

RSpec.describe ACE::PluginCache do
  let(:puppetserver_directory) { instance_double(File, '/foo/', readable?: true, file?: false, directory?: true) }
  let(:puppetserver_directory_path) { puppetserver_directory.path }
  let(:fake_file) { instance_double(File, "fake_file.rb", readable?: true, file?: true, directory?: false) }
  let(:fake_file_path) { fake_file.path }
  let(:params) { '?checksum_type=md5&environment=production&ignore=.hg&links=follow&recurse=true&source_permissions=' }
  let(:base_config) do
    {
      "ssl-cert" => "spec/fixtures/ssl/cert.pem",
      "ssl-key" => "spec/fixtures/ssl/key.pem",
      "ssl-ca-cert" => "spec/fixtures/ssl/ca.pem",
      "ssl-ca-crls" => "spec/fixtures/ssl/crl.pem",
      "file-server-uri" => "https://localhost:9999",
      "cache-dir" => "/tmp/environments"
    }
  end

  describe '#setup_ssl' do
    it {
      expect(described_class.new(base_config).setup_ssl).to be_a(Puppet::SSL::SSLContext)
    }
  end

  describe '#setup' do
    it {
      expect(described_class.new(base_config).setup).to be_a(described_class)
    }
  end

  describe '#sync' do
    it {
      allow(puppetserver_directory).to receive(:path).and_return('/foo/')
      allow(fake_file).to receive(:path).and_return('fake_file.rb')
      stub_request(:get, "https://localhost:9999/puppet/v3/file_metadatas/pluginfacts#{params}use")
        .to_return(
          status: 200,
          body: '[
            {
              "path":"/etc/puppetlabs/code/environments/production/modules",
              "relative_path":".","links":"follow","owner":0,"group":0,"mode":493,
              "checksum":{"type":"ctime",
                "value":"{ctime}2019-03-28 10:53:51 +0000"},
                "type":"directory","destination":null
            }
          ]', headers: { content_type: 'application/json' }
        )
      stub_request(:get, "https://localhost:9999/puppet/v3/file_metadata/pluginfacts")
        .to_return(status: 200, body: '{
          "message":"Not Found: Could not find file_metadata pluginfacts",
          "issue_kind":"RESOURCE_NOT_FOUND"
          }', headers: { content_type: 'application/json' })
      stub_request(:get, "https://localhost:9999/puppet/v3/file_metadatas/plugins#{params}ignore")
        .to_return(status: 200, body: "[
         {
           \"path\":\"#{puppetserver_directory_path}\",
           \"relative_path\":\".\",\"links\":\"follow\",
           \"owner\":999,\"group\":999,\"mode\":420,
           \"checksum\":{\"type\":\"ctime\",
           \"value\":\"{ctime}2019-03-28 10:53:51 +0000\"},\"type\":\"directory\",\"destination\":null
         },
         {
           \"path\":\"#{puppetserver_directory_path}\",
           \"relative_path\":\"#{fake_file_path}\",\"links\":\"follow\",
           \"owner\":999,\"group\":999,\"mode\":420,
           \"checksum\":{\"type\":\"md5\",
           \"value\":\"{md5}acbd18db4cc2f85cedef654fccc4a4d8\"},\"type\":\"file\",\"destination\":null
          }
         ]", headers: { content_type: 'application/json' })
      stub_request(:get, "https://localhost:9999/puppet/v3/file_metadata/plugins")
        .to_return(status: 200, body: "{
          \"path\":\"#{fake_file_path}\",
          \"relative_path\":null,\"links\":\"follow\",
          \"owner\":999,\"group\":999,\"mode\":420,
          \"checksum\":{\"type\":\"md5\",
          \"value\":\"{md5}acbd18db4cc2f85cedef654fccc4a4d8\"
          },\"type\":\"file\",\"destination\":null}", headers: { content_type: 'application/json' })
      stub_request(:get, "https://localhost:9999/puppet/v3/file_content/plugins/fake_file.rb?environment=production")
        .to_return(status: 200, body: "foo", headers: {})

      result = described_class.new(base_config).sync('production')
      folder_size = Dir[File.join(result, '**', '*')].count { |file| File.file?(file) }
      expect(folder_size).to eq 1
      expect(result).to be_a(String)
    }
  end
end
