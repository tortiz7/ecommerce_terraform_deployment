#!/bin/bash

sudo apt update

echo "${pub_key}" >> /home/ubuntu/.ssh/authorized_keys

curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

cd /home/ubuntu

git clone https://github.com/tortiz7/ecommerce_terraform_deployment.git
cd ecommerce_terraform_deployment/frontend || { echo "Failed to enter frontend directory"; exit 1; }

backend_ip=${backend_private_ip}

echo "backend_ip = $backend_ip"

if [ -z "$backend_ip" ]; then
  echo "Error: backend_private_ip is not set."
  exit 1
fi

sed -i "s/http:\/\/private_ec2_ip:8000/http:\/\/$backend_ip:8000/" package.json

npm i || { echo "npm install failed"; exit 1; }

export NODE_OPTIONS=--openssl-legacy-provider
npm start || { echo "npm start failed"; exit 1; }
