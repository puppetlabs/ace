# Recreating the Certs

The certs are used for local/docker testing and may need to be recreated if/when they have expired. At the time of writing this, the following command allows a new cert to be generated:

```
openssl x509 -req -extensions v3_req -days 3650 -sha256 -in aceserver.csr -CA ca.pem  -CAkey ca_key.pem -CAcreateserial -out cert.pem -extfile aceserver.cnf
```
