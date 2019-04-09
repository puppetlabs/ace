# frozen_string_literal: true

require 'puppet/configurer'

module ACE
  class Configurer < Puppet::Configurer
    # override the configurer to return the facts
    # related to the transport and the trusted
    # facts which is passed to the configurer.run
    def get_facts(options)
      transport_facts = Puppet::Node::Facts.indirection.find(Puppet[:certname],
                                                             environment: Puppet[:environment]).values
      trusted_facts = options[:trusted_facts]
      { transport_facts: transport_facts, trusted_facts: trusted_facts }
    end
  end
end
