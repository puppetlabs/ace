# used for the puppetserver in order
# for some modules to be installed and
# to relevant environments for testing
FROM puppet/puppetserver

RUN puppet module install puppetlabs-panos --environment production && \
    puppet module install puppetlabs-cisco_ios --environment production

RUN sed -i "s@# allow-subject-alt-names: false@allow-subject-alt-names: true@" /etc/puppetlabs/puppetserver/conf.d/ca.conf
