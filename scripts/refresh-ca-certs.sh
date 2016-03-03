#!/bin/bash
cd $(dirname $0)/..
mkdir -p certs
curl https://curl.haxx.se/ca/cacert.pem > certs/ca-certificates.crt
