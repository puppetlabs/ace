#!/bin/bash

/opt/puppetlabs/bin/puppet config set --section master node_terminus exec
/opt/puppetlabs/bin/puppet config set --section master external_nodes /usr/local/bin/enc.sh
