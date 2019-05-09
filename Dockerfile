# Install gems
FROM puppet/puppet-agent-alpine:6.4.2 as build

RUN \
apk --no-cache add build-base ruby-dev ruby-bundler ruby-json ruby-bigdecimal git openssl-dev && \
echo 'gem: --no-document' > /etc/gemrc && \
bundle config --global silence_root_warning 1

RUN mkdir /ace
# Gemfile requires gemspec which requires ace/version which requires ace
ADD . /ace
WORKDIR /ace
RUN rm -f Gemfile.lock
RUN bundle install --no-cache --path vendor/bundle

# Final image
FROM build
ARG ace_version=no-version
LABEL org.label-schema.maintainer="Network Automation Team <team-network-automation@puppet.com>" \
      org.label-schema.vendor="Puppet" \
      org.label-schema.url="https://github.com/puppetlabs/ace" \
      org.label-schema.name="Agentless Catalog Executor" \
      org.label-schema.license="Apache-2.0" \
      org.label-schema.version=${ace_version} \
      org.label-schema.vcs-url="https://github.com/puppetlabs/ace" \
      org.label-schema.dockerfile="/Dockerfile"

RUN \
apk --no-cache add ruby openssl ruby-bundler ruby-json ruby-bigdecimal git

COPY --from=build /ace /ace
WORKDIR /ace

EXPOSE 44633
ENV ACE_CONF /ace/config/docker.conf

ENTRYPOINT bundle exec puma -C config/transport_tasks_config.rb