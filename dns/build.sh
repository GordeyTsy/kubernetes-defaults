#!/bin/bash

#docker build --no-cache -t dnscrypt-proxy . > build.log 2>&1
docker build -t dnscrypt-proxy .
docker tag dnscrypt-proxy:latest registry:443/dnscrypt-proxy:latest
docker push registry:443/dnscrypt-proxy:latest
