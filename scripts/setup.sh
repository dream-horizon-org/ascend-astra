#!/usr/bin/env bash

# Install deck utility version 1.2.1
curl -fL https://github.com/Kong/deck/releases/download/v1.2.1/deck_1.2.1_darwin_amd64.tar.gz -o deck.tar.gz
tar -xf deck.tar.gz -C /tmp
sudo cp /tmp/deck /usr/local/bin/

python3 -m pip install pyyaml

# Install yq and gettext
brew install yq
brew install gettext

# docker and docker-compose must be present
docker run -d -p 1337:1337 --name konga -e "NODE_ENV=production" -e "TOKEN_SECRET=123456" pantsel/konga
echo "Konga is started at http://localhost:1337"

