# frozen_string_literal: true

require 'puppet'
# NOTE: Changes in puppet code loading results in simply requiring `puppet/configurer` no longer
# possible. The following requires can make ruby load, however selectively loading code from puppet
# will likely lead to issues in the future. Instead, just load puppet here.
# require 'puppet/util/autoload'
# require 'puppet/parser/compiler'
# require 'puppet/parser'
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
