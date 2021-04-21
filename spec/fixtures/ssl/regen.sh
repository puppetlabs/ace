#!/usr/bin/env bash

set -ex

# generate the key for the certificate authority
openssl genrsa -aes128 -out ca_key.pem -passout pass:password 2048

# make a certificate signing request but output a certificate signed by the CA
# key instead of a csr, include the common name of 'ca'
openssl req -new -key ca_key.pem -x509 -days 1000 -out ca.pem -subj /CN=ca -passin pass:password

# create a blank database file for the CA config
touch inventory

# create a CA emulator with a blank database and use that to generate a CRL
openssl ca -name ca -config <(echo database = inventory) -keyfile ca_key.pem -passin pass:password -cert ca.pem -md sha256 -gencrl -crldays 1000 -out crl.pem

# make a new CSR, also generating a private key with the subject name of 'boltserver'
openssl req -new -sha256 -nodes -out cert.csr -newkey rsa:2048 -keyout key.pem -subj /CN=boltserver

# generate a cert using the CSR generated above signed by CA key from the first operation
# and including the certificate extensions contained in the v3.ext file
openssl x509 -req -in cert.csr -CA ca.pem -CAkey ca_key.pem -CAcreateserial -out cert.pem -passin pass:password -days 999 -sha256 -extfile v3.ext

rm cert.csr ca.srl inventory