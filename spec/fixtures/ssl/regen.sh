#!/usr/bin/env bash

set -ex

openssl genrsa -aes128 -out ca_key.pem -passout pass:password 2048

openssl req -new -key ca_key.pem -x509 -days 1000 -out ca.pem -subj /CN=ca -passin pass:password

touch inventory

openssl ca -name ca -config <(echo database = inventory) -keyfile ca_key.pem -passin pass:password -cert ca.pem -md sha256 -gencrl -crldays 1000 -out crl.pem

openssl req -new -sha256 -nodes -out cert.csr -newkey rsa:2048 -keyout key.pem -subj /CN=boltserver

openssl x509 -req -in cert.csr -CA ca.pem -CAkey ca_key.pem -CAcreateserial -out cert.pem -passin pass:password -days 999 -sha256 -extfile v3.ext

rm cert.csr ca.srl inventory