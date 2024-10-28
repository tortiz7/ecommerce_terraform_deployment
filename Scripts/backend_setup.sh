#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y wget

# Download Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.0.linux-amd64.tar.gz
sudo mv node_exporter-1.6.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.6.0.linux-amd64*

# Create a service file for Node Exporter
cat <<EOL | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter

[Service]
User=ubuntu
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOL

# Start and enable Node Exporter
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

#install Python 3.9 and dependencies
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update -y
sudo apt install -y python3.9 python3.9-venv python3.9-dev python3-pip

# Clone github rep0
git clone https://github.com/tortiz7/ecommerce_terraform_deployment.git
cd ecommerce_terraform_deployment

# Create venv and install requirements
python3.9 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt

# Get metadata token and curl private IP of instance
aws_metadata_token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
backend_ip_address=$(curl -H "X-aws-ec2-metadata-token: $aws_metadata_token" http://169.254.169.254/latest/meta-data/local-ipv4)

# Replace placeholders with values passed from Terraform
sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = \[\"$backend_ip_address\"\]/" backend/my_project/settings.py
sed -i "s/'NAME': 'your_db_name'/'NAME': '$rds_db_name'/g" backend/my_project/settings.py
sed -i "s/'USER': 'your_username'/'USER': '$rds_db_user'/g" backend/my_project/settings.py
sed -i "s/'PASSWORD': 'your_password'/'PASSWORD': '$rds_db_password'/g" backend/my_project/settings.py
sed -i "s/'HOST': 'your-rds-endpoint.amazonaws.com'/'HOST': '$rds_endpoint'/g" backend/my_project/settings.py
#Create the tables in RDS: 
python backend/manage.py makemigrations account
python backend/manage.py makemigrations payments
python backend/manage.py makemigrations product
python backend/manage.py migrate

#Migrate the data from SQLite file to RDS:
python backend/manage.py dumpdata --database=sqlite --natural-foreign --natural-primary -e contenttypes -e auth.Permission --indent 4 > datadump.json

python backend/manage.py loaddata datadump.json


# Deploy Django application
python backend/manage.py runserver 0.0.0.0:8000
