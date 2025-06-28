#!/bin/bash

docker build -t node-svc:latest .
docker run --rm -p 8080:8080 -e PORT=8080 \
      node-svc:latest
