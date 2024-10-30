#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y wget

echo "${pub_key}" >> /home/ubuntu/.ssh/authorized_keys

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

sudo systemctl status node_exporter || { echo "Node Exporter failed to start"; exit 1; }

#install Python 3.9 and dependencies
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update -y
sudo apt install -y python3.9 python3.9-venv python3.9-dev python3-pip

cd /home/ubuntu

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
rds_db_name=${RDS_DB_NAME}
rds_db_user=${RDS_DB_USER}
rds_db_password=${RDS_DB_PASSWORD}
rds_address=${RDS_ADDRESS}

if [ -z "$rds_db_name" ] || [ -z "$rds_db_user" ] || [ -z "$rds_db_password" ] || [ -z "$rds_address" ]; then
    echo "One or more required variables are not set. Exiting."
    exit 1
fi

echo "rds_address = $rds_address"

cd backend

# Replace placeholders with values passed from Terraform
sed -i '89,96 s/^# //' my_project/settings.py
sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = \[\"$backend_ip_address\"\]/" my_project/settings.py || { echo "Failed to update ALLOWED_HOSTS in settings.py"; exit 1; }
sed -i "s/'NAME': 'your_db_name'/'NAME': '$rds_db_name'/g" my_project/settings.py || { echo "Failed to update database NAME in settings.py"; exit 1; }
sed -i "s/'USER': 'your_username'/'USER': '$rds_db_user'/g" my_project/settings.py || { echo "Failed to update database USER in settings.py"; exit 1; }
sed -i "s/'PASSWORD': 'your_password'/'PASSWORD': '$rds_db_password'/g" my_project/settings.py || { echo "Failed to update database PASSWORD in settings.py"; exit 1; }
sed -i "s/'HOST': 'your-rds-endpoint.amazonaws.com'/'HOST': '$rds_address'/g" my_project/settings.py || { echo "Failed to update database HOST in settings.py"; exit 1; }

#Create the tables in RDS: 
python3 manage.py makemigrations account || { echo "Migrations for account failed"; exit 1; }
python3 manage.py makemigrations payments || { echo "Migrations for payments failed"; exit 1; }
python3 manage.py makemigrations product || { echo "Migrations for product failed"; exit 1; }
python3 manage.py migrate || { echo "Migrate failed"; exit 1; }

# Migrate the data from SQLite file to RDS:
python3 manage.py dumpdata --database=sqlite --natural-foreign --natural-primary -e contenttypes -e auth.Permission --indent 4 > datadump.json

if [ ! -f datadump.json ]; then
    echo "datadump.json not found, loaddata will fail"
    exit 1
fi

# Load the data into RDS
python3 manage.py loaddata datadump.json || { echo "Loaddata failed"; exit 1; }

# Deploy Django application
python3 manage.py runserver 0.0.0.0:8000
