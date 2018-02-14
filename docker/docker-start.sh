#!/bin/bash

cd /data/helpkit/current

ssh-keyscan -t rsa github.com > ~/.ssh/known_hosts

bundle check || bundle install #Check and install missing gems before starting the server

bundle exec rails server --port 3000 --binding 0.0.0.0