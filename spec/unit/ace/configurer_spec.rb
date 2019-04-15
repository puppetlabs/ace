# frozen_string_literal: true

require 'spec_helper'
require 'ace/configurer'
require 'puppet/configurer'

RSpec.describe ACE::Configurer do
  let(:configurer) { described_class.new }
  let(:indirection) { instance_double(Puppet::Indirector::Indirection, 'indirection') }
  let(:node_facts) { instance_double(Puppet::Node::Facts, 'node_facts') }
  let(:options) do
    {
      trusted_facts: {
        'foo' => 'cat'
      }
    }
  end
  let(:transport_facts) do
    {
      'cat' => 'dog'
    }
  end

  describe "#get_facts" do
    before do
      allow(Puppet::Node::Facts).to receive(:indirection).and_return(indirection)
      allow(indirection).to receive(:find).and_return(node_facts)
      allow(node_facts).to receive(:values).and_return(transport_facts)
    end

    it 'returns the trusted facts' do
      expect(configurer.get_facts(options)).to eq(transport_facts: { "cat" => 'dog' },
                                                  trusted_facts: { "foo" => "cat" })
    end
  end
end
