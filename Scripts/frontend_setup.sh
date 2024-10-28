#!/bin/bash

sudo apt update

curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

git clone https://github.com/tortiz7/ecommerce_terraform_deployment.git
cd ecommerce_terraform_deployment/frontend || { echo "Failed to enter frontend directory"; exit 1; }

if [ -z "$backend_private_subnet" ]; then
  echo "Error: backend_private_subnet is not set."
  exit 1
fi

sed -i 's/http:\/\/private_ec2_ip:8000/http:\/\/'"$backend_private_subnet"':8000/' package.json

npm i || { echo "npm install failed"; exit 1; }

export NODE_OPTIONS=--openssl-legacy-provider
npm start || { echo "npm start failed"; exit 1; }

