# used for the puppetserver in order
# for some modules to be installed and
# to relevant environments for testing
FROM puppet/puppetserver:6.14.1

COPY ./fixtures/conf/auth.conf /etc/puppetlabs/puppetserver/conf.d/
COPY ./fixtures/conf/enc.sh /usr/local/bin/enc.sh
COPY ./fixtures/conf/configure-enc.sh /docker-entrypoint.d/85-configure-enc.sh

RUN puppet module install puppetlabs-panos --environment production && \
    puppet module install puppetlabs-cisco_ios --environment production && \
    puppet module install puppetlabs-test_device --environment production && \
    cp -a $(puppet config print environmentpath)/production $(puppet config print environmentpath)/something_else && \
    chmod +x /usr/local/bin/enc.sh
