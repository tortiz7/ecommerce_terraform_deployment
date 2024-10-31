# Microblog Deployment on Self-Provisioned VPC, Infrastructure and Monitoring

---
### PURPOSE

Hello! If you've been following my Workload series for deploying Flask Applications using AWS infrastructure, then welcome to the fifth entry. The purpose of Workload 5 is to implement a resilient and robust infrastrcture for a new ecommerce web application, this time focusing on expanding availability by using Infrastructure-as-code in the form of Terraform to automate the build process for our infrastructure across two Availability Zones. This Workload emphasizes best practices in cloud deployment, including automating the building of infrastructure with Terraform, continuous integration and continuous delivery (CI/CD) with Jenkins, effective resource management across multiple EC2 instances in different subnets and AZ's, and a strong emphasis on monitoring and security. By establishing a clear separation between deployment and production environments, this project aims to enhance system reliability while optimizing resource utilization and operational efficiency.

---
## STEPS

**Create the Terraform_Jenkins EC2:**

**Why:** An EC2 housing Terraform and Jenkins will be at the crux of this Workload deployment. This EC2 will be where you will build out the initial Terraform root directory, with your main.tf orchestrating the passing of variables to all the other modules necessary for our infrastructure in their child directories. Jenkins, our old friend, will be the CI/CD tool that continuously integrates new code - both the source code of our ecommerce app and the code for our Terraform build - into the Jenkins pipeline, ensuring everything is logically sound and tested prior to deployment. We will also install VScode on this server so we can more easily write all of our Terraform files. 

**How:**
 
1. Navigate to the EC2 services page in AWS and click "Launch Instance".
2. Name the EC2 `Jenkins` and select "Ubuntu" as the OS Image.
3. Select a t3.medium as the instance type.
4. Create a new key pair (and be sure to save the .pem somewhere safe!). 
5. In "Network Settings", choose the default VPC selected for this EC2, with Auto-Assign Public IP enabled.
6. Create a Security Group that allows inbound traffic to the services and applications the EC2 will need and name it after the EC2 it will control.
7. The Inbound rules should allow network traffic on Ports 22 (SSH) and 8080 (Jenkins) and port 8081 (Vscode), and all Outbound traffic.
8. Launch the instance!

**The Jenkins EC2**
1. Navigate to the EC2 services page in AWS and click "Launch Instance".
2. Name the EC2 `Jenkins` and select "Ubuntu" as the OS Image.
3. Select a t3.medium as the instance type.
4. Select the key pair you just created as your method of SSH'ing into the EC2.
5. In "Network Settings", keep the default VPC selected for this EC2, with Auto-Assign Public IP enabled.
6. Create a Security Group that allows inbound traffic to the services and applications the EC2 will need and name it after the EC2 it will control.
7. The Inbound rules should allow network traffic on Ports 22 (SSH) and 8080 (Jenkins), and all Outbound traffic.
8. Launch the instance!

### Install Jenkins, Terraform and VScode
- **Why**: Jenkins automates the build and deployment pipeline. It pulls code from GitHub, tests it, and handles deployment once the Jenkinsfile is configured to do so. Terraform will help us automate the provisioning of the EC2's, RDS, VPC and all it's related components. Finally, Vscode will give us a much more manageable terminal for writing all the modules and scripts we'll need to create all the infrastructure. 
  
- **How**: I created and ran the below script to install Jenkins, and it's language prerequisite Java (using Java 17 for this deployment). To save time, the script also updates and upgrades all packages included in the EC2, ensuring they are up-to-date and secure. 

``` bash
#!/bin/bash
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y openjdk-17-jdk
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5BA31D57EF5975CA
sudo apt update -y
sudo apt install -y jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins
```

`chmod +x` the script to make it executable, and then run it to install everything within.

Next, we'll create and run a script for installing Terraform:

```bash
#!/bin/bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get install terraform
```

Don't forget to `chmod+x` this script as well!

And finally, our VScode install script:

```bash
#!/bin/bash
curl -L https://code-server.dev/install.sh | sh
sudo systemctl enable --now code-server@$USER
sleep 1
sudo systemctl restart code-server@$USER
CONFIG_PATH="$HOME/.config/code-server/config.yaml"
echo "bind-addr: 0.0.0.0:8081
auth: password
password: <set_your_password>
cert: false" > "$CONFIG_PATH"
```

`chmod +x` this script, and we're ready to roll!

### Creating our Terraform Infrastructure

## Root Directory

**Why:** This is the big one! Terraform will allow us to spin up the whole infrastructure in one go, provided we have all of our modules, resource blocks, outputs, variables and scripts in order. In the next couple steps, I'll show you how to configure your Terraform files to ensure that everything is correct and you can spin up the infrastructure without issue. Note that I have included all my Terraform files in this GitHub directory, so you could theoretically just git clone this repo and use my already-correct Terraform files to automate the creation of the infrastructure via Jenkins - but I'll give you a high level overview of how everything works so you can do it yourself and forgo my files for learning purposes!

**How:** 

First, navigate to your VSCode terminal by putting this in your address bar: http://<your_ec2_public_ip:8081>

	- Create a directory called Terraform with `mkdir Terraform`
	- In this directory, run `Terraform init` so you can begin running Terraform commands
	- Now let's create the main.tf file. This file will be the telephone board operator for all of your modules - and there will be plenty! As the operator, it deals in connecting variables, not calls - every variable that your other modules need, will first pass through this main.tf before going to the module. It'll all make sense as we go through the module setups. 
	- Your main.tf should look like this. Note the provider block - it's the only place it will appear in your Terraform build, and it will pass along critical variables to your other modules to ensure AWS ties their access together with your access key, allowing you to access all the infrastructure once it's created: 

```hcl
provider "aws" {
  access_key = var.aws_access_key          # Replace with your AWS access key ID (leave empty if using IAM roles or env vars)
  secret_key = var.aws_secret_key          # Replace with your AWS secret access key (leave empty if using IAM roles or env vars)
  region     = var.region              # Specify the AWS region where resources will be created (e.g., us-east-1, us-west-2)
}


module "VPC"{
  source = "./VPC"
} 

module "EC2"{
  source = "./EC2"
  vpc_id = module.VPC.vpc_id
  public_subnet = module.VPC.public_subnet
  private_subnet = module.VPC.private_subnet
  instance_type = var.instance_type
  region = var.region
  frontend_count = var.frontend_count
  backend_count = var.backend_count
  db_name = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  rds_address = module.RDS.rds_address
  postgres_db = module.RDS.postgres_db
  rds_sg_id = module.RDS.rds_sg_id
  alb_sg_id = module.ALB.alb_sg_id
  frontend_port = var.frontend_port


}

module "RDS"{
  source = "./RDS"
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  vpc_id            = module.VPC.vpc_id
  private_subnet    = module.VPC.private_subnet
  backend_sg_id     = module.EC2.backend_sg_id

  
}

module "ALB"{
  source = "./ALB"
  alb_name = var.alb_name
  backend_port = var.backend_port
  frontend_port = var.frontend_port
  backend_count = var.backend_count
  frontend_count = var.frontend_count
  frontend_server_ids = module.EC2.frontend_server_ids
  public_subnet = module.VPC.public_subnet
  vpc_id = module.VPC.vpc_id

}

Four modules! I know it's all showing up as red in your Vscode terminal right now, but as we create our child directories, corresponding main.tfs and output.tfs, it'll start clearing up!

	- Next, we will create our variables.tf. This will assign the value for many of the variables that we will be passing along to our child directories and Root main.tf. Not all of the variables will have their values declared here, though - some of them will be assigned value as their respective resource is created in the Child directories, and then their value will be routed back to the Root main.tf, where the variable will be placed in the Module block that has to use it. 
	- Take vpc_id for instance. That will not be found in our Root variable.tf, because the id is dependent on the creation of the VPC first. So the VPC will be created, and then in the output.tf of our VPC child directory, we will create the variable and assign it the value of the VPC ID that was created. That is why, in our EC2 Module, it is listed as `vpc_id = module.VPC.vpc_id` - you have to add the path of where the variable was created in the main.tf of the Root module, so that I can properly pass the value to the module that needs it. 
	- Here's the variables.tf for the Root directory:

```hcl
 variable aws_access_key{
    type = string
    sensitive = true

 }                                                   
 
 variable aws_secret_key{
    type = string
    sensitive = true

 }                                       

variable region{
}

 variable instance_type{
 }  

variable "frontend_count"{
  type = number
  default = 2
}

variable "backend_count"{
  type = number
  default = 2
}
 variable "db_instance_class" {
  description = "The instance type of the RDS instance"
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "ecommercedb"
}

variable "db_username" {
  description = "Username for the master DB user"
  type        = string
  sensitive = true
}

variable "db_password" {
  description = "Password for the master DB user"
  type        = string
  sensitive = true
}

variable "alb_name" {
  default = "frontend-backend-alb"
}

variable "backend_port" {
  default = 8000
}

variable "frontend_port" {
  default = 3000
}
```

With this variables.tf in front of you, can see what I mean by passing a variable that was outputted by a Child directory to the main.tf, and passing one that is created in the root variables.tf. Take for instance the `instance_type` variable in our EC2 module - Instead of using a module path when assigning the value, since we have it in our Root variables.tf file, we use `instance_type = var.instance_type` instead, referencing the value in the Root variables.tf instead. 

	- The next terraform file we need here is an important one - terraform.tfvars. This file will pass along variables that we've labelled as "secret" in our variables.tf file. These variables are one sthat we do not want publicly accessible, lest they could fall into the hands of a bad actor - files like our access_key and secret access_key. We will add this into our Jenkins file via Jenkins Credential Manager once we get to that step! 
	- Here's what it should look like:
```hcl

aws_access_key = "your_access key"       
aws_secret_key = "your_secret_key"
instance_type = "t3.micro"
db_username = "your_db_username"
db_password = "your_db_password"
frontend_count = 2
backend_count = 2
```

This will help us automate the build without compromising our security!

	- Now, we will work on scripts! We will write three scripts, that we will put in the user_data section of our EC2s so that they will run when the EC2 is created. This will ensure that the EC2's correctly install and start every service and dependency we need for our Ecommerce Django application. This is in the "Root Directory" section of the readme, because it's easier to path the files to the user_data field if they are in the root directory. 
	- Here is our first user_data script: `frontend_setup.sh`

```bash
#!/bin/bash

sudo apt update

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
```

This script will install node.js unto the newly created front-end EC2, then it'll clone my github repo with the source code unto the EC2, then it will pipe in the backend_server EC2's private IP (which I will show you how to do in the EC2 Module section), so that we can use it in a sed command to replace placeholder text in our package.json file in the github repo, which will allow our React webserver to forward traffic to the backend_server's Django application on port 8000. As you may recall from WL4, since they frontend and backend servers are on the same VPC, they can communicate via their private IP.  `npm i` installs all the dependencies as listed in our package.json file, and `NODE_OPTIONS--openssl-legacy-provider` allows our outdated dependencies to be compatible with every other part of our infrastructure. Finally, we use npm start to start the React webserver. We also error handling all along the script to help us troubleshoot any errors once the EC2 has spun up. To see the output of this script, as well as all the steps taken to create the EC2's, use this command: `cat /var/log/cloud-init-output.log`

	- Next, we will create our first backend_setup.sh for the user_data for our backend EC2s. This will prepare both of the backend_servers to run django, as well as connect them to the RDS database that we will be setting up with Terraform as well. Here's the script:

```hcl
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
```


This script will first update the packages already on the EC2, then install Node Exporter, then create a system daemon to control Node Exporter, then install python 3.0 and the dependencies will we need to run commands on this server, then git clone my repo with the application source code in the ubuntu home directory. Then we create a venv, activate it, and install all the dependencies outlined in the requirements.txt file found in our backend folder. Then, we get a metadata token from AWS, save it to a variable, and then use it to curl the backend_ip for the server the script is running on, so that we can then sed that backend_ip (after saving it to a variable) into necessary fields to in our settings.py file, allowing us to automate the process of joining the Django app to our newly provisioned RDS postgresql database. We pass along 5 4 different variables from the RDS module (I'll show you how in the next section), which we also sed into their respective field in the settings.py file. Then, we migrate all the tables and data in our sqlite.db to a dtatadump.json file, and then load that datadump.json into our new postgresql DB, which is more powerful, spacious, and capable of handling the level of transactions required of our ecommerce application. Finally, we launch the django application on port 8000. 

	- Our final user_data script for the backend_servers does much the same as the first, except it does not repeat the migration of all of our data in the sqlite.db into the postgresql DB, as that will result in duplication errors that will leave the EC2 unable to connect to the new DB. Instead it just changes the settings.py fields again via sed, and then migrates the data out of the sqlite.db so that the new back_end server does not default to using the data in that database instead of our Postgresql one. Since Postgresql DB is serving as our source of truth for data across both of the backend_servers (and thus, across two AZ's), it's paramount that they both connect, add and manipulate data in that DB. 
	- Here's the script:

```bash
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

python3 manage.py makemigrations account || { echo "Migrations for account failed"; exit 1; }
python3 manage.py makemigrations payments || { echo "Migrations for payments failed"; exit 1; }
python3 manage.py makemigrations product || { echo "Migrations for product failed"; exit 1; }
python3 manage.py migrate || { echo "Migrate failed"; exit 1; }

python3 manage.py runserver 0.0.0.0:8000
```

That's all for the root directory! Now, for our first module - the VPC!

## Child Directory - VPC

**Why:** The first child directory we will create is for VPC, which will correspond with our VPC module in the root main.tf. We will make this as a sub-directory of our Terraform directory, and then we will create 3 Terraform files in that sub-directory: main.tf, variables.tf and outputs.tf. `main.tf` will be where we create the various resource blocks we will need for our VPC to function correctly across multiple AZ's, it'll create our 2 public and 2 private subnets, their route tables, and the Internet Gateway and NAT Gateway that will be associated with them. Then, we will create an outputs.tf, which will output the value of variables that are associated with parts of the VPC infrastructure, to be used in our other child directories - this is why our VPC gets built first, as it has the most output variables that our other modules will rely on. It also does not need to declare any variables from our Root or other modules, so that's another reason to create it first!

**How:** Let's start with the main.tf. Create a new file in the newly created `VPC` directory called `main.tf`, and model it after my main.tf file below:

```hcl
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "wl5vpc"
  }
}

resource "aws_subnet" "public" {
  count = 2
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-${count.index +1}"
  }
}

resource "aws_subnet" "private" {
  count = 2
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
  availability_zone = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "Private-${count.index +1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "IGW"
  }
}

resource "aws_eip" "nat_ip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_ip.id
  subnet_id     = aws_subnet.public[0].id 

  tags = {
    Name = "NAT-Gateway"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public_Route_Table"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "Private_Route_Table"
  }
}

resource "aws_route_table_association" "igw_assn" {
 count = length(aws_subnet.public)  
 subnet_id = aws_subnet.public[count.index].id  
 route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_assn" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

There's a ton of important resource blocks in there! I broke down most of their use cases in there, and you can ascertain the need for the rest from my previous Workload 4 deployment. 

	- Now, let's create the outputs.tf file. Create a new file in the `VPC` directory called `outputs.tf`, and model it after my file below:

```hcl
output "vpc_id" {
    value = aws_vpc.main.id
}

output "public_subnet"{
    value = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet"{
    value = [for subnet in aws_subnet.private : subnet.id]
}
```

These output variables will be used in basically all our other modules, so it's great that we have then outputted first! That's all for our VPC child directory, so let's build out the next one - possibly our most important - the EC2 child directory!


## Child Directory - EC2

**Why:** Next up: our EC2 Module. Create the Child directory for the EC2 in the same manner as the VPC - navigate back to the root `Terraform` directory, and then create a new directory called `EC2`. We'll then create a main.tf, outputs.tf, and this time, a variables.tf as well to list the variables we will need to declare and pass into our EC2 module to assist in the building out of our EC2 instances, security groups, and other components.

**how:** Let's start with the main.tf file. While in the `EC2` child directory, create a file called `main.tf` and model it after the one I have below:

```hcl

locals{
  pub_key = file("kura_public_key.txt")
  backend_private_ips = aws_instance.backend_server[*].private_ip
}

resource "aws_instance" "backend_server" {
  count = var.backend_count
  ami = "ami-0866a3c8686eaeeba"                # The Amazon Machine Image (AMI) ID used to launch the EC2 instance.
                                        # Replace this with a valid AMI ID
  instance_type = var.instance_type                # Specify the desired EC2 instance size.
  # Attach an existing security group to the instance.
  # Security groups control the inbound and outbound traffic to your EC2 instance.
  vpc_security_group_ids = [aws_security_group.backend_sg.id]         # Replace with the security group ID, e.g., "sg-01297adb7229b5f08".
  key_name = "WL5"                # The key pair name for SSH access to the instance.
  subnet_id = var.private_subnet[count.index % length(var.private_subnet)]
  user_data = count.index == 0 ? templatefile("backend_setup_0.sh", {
    RDS_DB_NAME = var.db_name
    RDS_DB_USER = var.db_username
    RDS_DB_PASSWORD = var.db_password
    RDS_ADDRESS = var.rds_address
    pub_key = local.pub_key
  }) : templatefile("backend_setup_1.sh", {
    RDS_DB_NAME = var.db_name
    RDS_DB_USER = var.db_username
    RDS_DB_PASSWORD = var.db_password
    RDS_ADDRESS = var.rds_address
    pub_key = local.pub_key
  })

  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_backend_az${count.index +1}"         
  }

  depends_on = [var.postgres_db]
}

resource "aws_instance" "frontend_server" {
  count = var.frontend_count
  ami = "ami-0866a3c8686eaeeba"                # The Amazon Machine Image (AMI) ID used to launch the EC2 instance.
                                        # Replace this with a valid AMI ID
  instance_type = var.instance_type                # Specify the desired EC2 instance size.
  # Attach an existing security group to the instance.
  # Security groups control the inbound and outbound traffic to your EC2 instance.
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]         # Replace with the security group ID, e.g., "sg-01297adb7229b5f08".
  key_name = "WL5"                # The key pair name for SSH access to the instance.
  subnet_id = var.public_subnet[count.index % length(var.public_subnet)]
  user_data = templatefile("frontend_setup.sh", {
    backend_private_ip = local.backend_private_ips[count.index % length(local.backend_private_ips)]
    pub_key = local.pub_key
  })
  
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_frontend_az${count.index +1}"         
  }

  depends_on = [aws_instance.backend_server]
}

# Create a security group named "tf_made_sg" that allows SSH and HTTP traffic.
# This security group will be associated with the EC2 instance created above.
resource "aws_security_group" "frontend_sg" { # in order to use securtiy group resouce, must use first "", the second "" is what terraform reconginzes as the name
  name        = "tf_made_sg"
  description = "open ssh traffic"
  vpc_id = var.vpc_id
  # Ingress rules: Define inbound traffic that is allowed.Allow SSH traffic and HTTP traffic on port 8080 from any IP address (use with caution)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

     ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
  # Egress rules: Define outbound traffic that is allowed. The below configuration allows all outbound traffic from the instance.
 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Tags for the security group
  tags = {
    "Name"      : "frontend_SG_tf_made"                          # Name tag for the security group
    "Terraform" : "true"                                # Custom tag to indicate this SG was created with Terraform
  }
}

resource "aws_security_group" "backend_sg" { # in order to use securtiy group resouce, must use first "", the second "" is what terraform reconginzes as the name
  name        = "tf_made_sg_private"
  description = "host gunicorn"
  vpc_id = var.vpc_id
  # Ingress rules: Define inbound traffic that is allowed.Allow SSH traffic and HTTP traffic on port 8080 from any IP address (use with caution)
   
   ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    } 

 ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    #   ingress {
    # from_port   = 5432
    # to_port     = 5432
    # protocol    = "tcp"
    # cidr_blocks = ["0.0.0.0/0"]
    # }


     egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

 # Tags for the security group
  tags = {
    "Name"      : "backend_SG_tf_made"                          # Name tag for the security group
    "Terraform" : "true"                                # Custom tag to indicate this SG was created with Terraform
    }
}

  resource "aws_security_group_rule" "backend_to_rds_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend_sg.id
  source_security_group_id = var.rds_sg_id
}

resource "aws_security_group_rule" "allow_alb_to_frontend" {
  type              = "ingress"
  from_port         = var.frontend_port
  to_port           = var.frontend_port
  protocol          = "tcp"
  security_group_id = aws_security_group.frontend_sg.id  

  source_security_group_id = var.alb_sg_id  
}


output "instance_ip" {
 value = [for instance in aws_instance.frontend_server : instance.public_ip]  # Display the public IP address of the EC2 instance after creation.
}
```

First thing I want to draw your attention to in this EC2 main.tf is the count parameter. Count allows us to dynamically scale the amount of EC2's created by Terraform. I have mine set to a variable, so I can easily change the count anywhere the variable is referenced (I have it set to 2). You'll see `[count.index]` sprinkled around the file as well - that allows us to  make changes to each front_end and back_end server that is created via the count argument by iterating through the count. 

Next, look at the user_data fields in each of the EC2 instance resource blocks. We've already gone over there function - to run scripts at the inception of the EC2 instances - but let's talk about how we're doing some of that. The user_data file uses a templatefile() to pass variables declared in Terraform to the script, so that they can be used to run necessary commands in the script, such as using sed to add the backend_private_ip to the packages.json file, or passing all of the needed RDS information into the settings.py file. Notice how we leverage count.index to run two different user_data scripts on each of our generated backend EC2 servers - `count.index ==  0 ?` sets a conditional, where if the first EC2 is created (the first one being 0), then our first script will run, the one that migrates all the tables from sqlite.db to postgresql. Since that was is created, the second will register as FALSE to the expression, and the second script will run on that instance instead - the one that does not include the migration to our new DB. This helps us avoid the issue of data redundancy in our new DB. 

Last thing to look at - depends_on! We use depends_on to control when our resources are created, in relation to whether or not a different resource it is reliant on is already created. For our EC2 module, we have `depends_on` in two resource blocks - our backend_servers depend on the existence of the RDS (so that the user_data scripts have a DB to migrate the data into), and our frontend_servers are dependent on the exsistence of our backend_servers existing (so that the variable for their private IP's can be passed into the frontend_setup.sh user_data scripts). Are you starting to see the power and modularity of Terraform yet?

Let's just go over the security groups quickly. We have two security groups - one for both of our frontend servers, and one for both of our backend servers. Our frontend servers have these ports open: 22 for SSH, 80 for http access, 3000 for our React web server to listen in on for network traffic, and we have all ports open for egress. Our backend servers have port 22 open, again for SS, port 8000 open for our Django application, and port 9100 for Node Exporter (I know you missed monitoring!). We have two special resource blocks for specific securtiy group allow rules - one that opens port 5432 on our backend servers to allow our RDS to send and receive data from the backend_servers, and one that explicitly allows our Application Load Balancer to direct network traffic to our frontend server's React webserver on port 3000. 

 - Alright, with the main.tf out the way, let's create our variables.tf file. In your `EC2` child directory, create a new file, call it `variables.tf`, and model it after my file below:

```hcl
 variable region{
 }     

 variable instance_type{
 }  

 variable "vpc_id"{
 }

 variable "public_subnet"{
 }

 variable "private_subnet"{
 }

 variable "frontend_count"{
 }

 variable "backend_count"{
 }

 variable "db_name"{
 }

 variable "db_username"{
 }

 variable "db_password"{
 }

 variable "rds_address"{
 }

 variable "postgres_db"{
 }

variable "rds_sg_id" {
 }
 
variable "alb_sg_id"{
}

variable "frontend_port"{
}
```

As you may have been able to tell just by looking at the EC2 main.tf, there are many variables that we have to declare in order to make our EC2's function correctly and connect to the many different components of our Terraform-created infrastructure, the most out of any of our variables.tf. It's pulling variables from every single other module in the Terraform directory structure, which makes sense if you think about - the EC2's are where all the action happens, where the application is deployed and network traffic to it is handled, so it would need to be able to interface with every other part of our ecosystem. 

	- And finally, our outputs.tf file. Not too many in this one. Create a new file called `outputs.tf` in your EC2 child directory, and model it after my file below

```hcl
output "backend_sg_id" {
    value = aws_security_group.backend_sg.id
}

output "frontend_server_ids" {
  value = [for instance in aws_instance.frontend_server : instance.id]
}
```

This will allow our other modules to use these variables to create and deploy their respective parts of the infrastructure.

## Child Directory - RDS

**Why:** We are migrating all the data in our source code's sqlite.db from that lightweight database to PostgreSQL, managed by Amazon RDS, for numerous reasons: PostgreSQL is capable of handling concurrent connections, crucial for an ecommerce website deployed across multiple AZ's; it supports advanced data types, such as JSON arrays, which aids tremendously in manipulating the data stored in its tables; and leveraging RDS allows us to use the DB as a single source of truth for both of our instances of the Django application, allowing us to safely manipulate all the data that comes in through our ecommerce website. 

**How:** The how is the same as the last 2 child directories, so we'll speed through this one. Navigate back to the `Terraform` root directory, create a new directory called `RDS`, and cd into there. 

	- Here's our main.tf file below for the RDS Child directory - model yours after it:

```hcl
resource "aws_db_instance" "postgres_db" {
  identifier           = "ecommerce-db"
  engine               = "postgres"
  engine_version       = "14.13"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  storage_type         = "standard"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres14"
  skip_final_snapshot  = true

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "Ecommerce Postgres DB"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = var.private_subnet

  tags = {
    Name = "RDS subnet group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS Security Group"
  }
}

resource "aws_security_group_rule" "rds_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id  
  source_security_group_id = var.backend_sg_id            
}
```

	- Here's our variables.tf file for the RDS Child directory - model away!:


```hcl
variable "db_instance_class" {
}

variable "db_name" {
}

variable "db_username" {
}

variable "db_password" {
}

 variable "private_subnet"{
    type = list(string)
 }

 variable "vpc_id"{
 }
 
 variable "backend_sg_id" {
 }
```

	- And finally, here's our outputs.tf for the RDS Child directory - feel free to use it:


```hcl
output "rds_address" {
  value = aws_db_instance.postgres_db.address
}

output "rds_sg_id" {
    value = aws_security_group.rds_sg.id
}

output "postgres_db"{
  value = aws_db_instance.postgres_db.id
}
```

## Child Directory: ALB

**Why:** If you've been following my Workload series of infrastructure provisioning and application deployments, then you may realize that this is the first time we are using an Application Load Balancer. Why is that, you might be wondering. Well, that's because we have 2 AZ's for the first time! The Application Load Balancer is the gateway to our Django application - it will be the first point of contact for all network traffic trying to reach our application, and it will route that traffic to the most available frontend_server to that client, cutting down on network lag for the user and allowing us to better manage our resources. If one of the frontend servers go down, it will route the traffic to the other server, maintaining availability to our application and increasing it's overall resiliency. This is what being a DevOps engineer is all about!

**How:** The how is just like the other three Child directories, so we'll make this quick. Return to your `Terraform` Root directory, create a new directory called `ALB`, and let's start making our final batch of terraform files!

	- First, the main.tf file for the ALB Child directory - model yours after it:

```hcl

resource "aws_security_group" "alb_sg" {
  name   = "alb_sg"
  vpc_id = var.vpc_id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    description = "Allow HTTP traffic"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

egress {
    description = "Allow all outbound traffic"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_lb" "frontend_alb" {
  name               = var.alb_name
  internal           = false  
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "frontend_tg" {
  name     = "frontend-target-group"
  port     = var.frontend_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = "/health"  
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "frontend_tg_attachment" {
  count            = var.frontend_count  
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = var.frontend_server_ids[count.index]  
  port             = var.frontend_port  
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.frontend_alb.dns_name
  description = "The DNS name of the frontend ALB"
}

	- Next, our variables.tf for the ALB Child Directory:
variable "alb_name"{
}

variable "backend_port"{
}

 variable "frontend_count"{

 }
 variable "frontend_port"{
   
 }
variable "backend_count"{
}

variable "frontend_server_ids"{
}

variable "public_subnet"{
}

variable "vpc_id"{
}
```

And that's all for Terraform! In your Terraform root directory, run a `terraform validate` command to ensure all the pieces are correctly placed, all variables are being outputted and called correctly, and there are no issues with syntax. If that passes, then run a `terraform plan` command so you can see the blueprint of every piece of infrastructure that will be created, right in your terminal. And once you are satisfied with that, it's time to build: run `terraform apply` and watch the magic happen! It'll take around 6 to 7 minutes to provision all the infrastructure, but if it worked correctly, then you should be able to navigate to AWS, find your Load Balancer DNS address, and put that in your address bar to connect to the ecommerce website! If you see all the products available for purchase, then congrats, you did it correctly!

Now, tear it all down with `terraform destroy`! It's time to really automate this deployment, with - drum roll please - Jenkins!

## Jenkins Pipeline

**Why:** Jenkins is going to take this deployment over the top, building the source code, testing it thoroughly, and then running it's own terraform commands to build and deploy the infrastructure, all in one go!

**How:** First, git clone this repo to your Terraform_Jenkins EC2. Then mv the full contents of your Terraform root directory (which will include all the subdirectories and user_data scripts) into a folder called `Terraform` in the new GitHub Repo (you can delete my files, I don't mind). Once that's done, navigate to the Jenkins UI, create a multi-branch pipeline, add your GitHub Credentials to it, and then - WAIT! Before we can initiate the Jenkins pipeline, we need to add our AWS Access and Secret Keys to Jenkins Credential Manager so it can actually use Terraform on the EC2 it's installed on. To do so: 

	1. Navigate to the Jenkins Dashboard and click on "Manage Jenkins" on the left navagation panel.
	2.  Under "Security", click on "Credentials".
	3.  You should see the GitHub credentials you just created here.  On that same line, click on "System" and them "Global credentials (unrestricted)". (You should see more details about the GitHub credentials here (Name, Kind, Description))
	4.  Click on "+ Add Credentials"
	5.  In the "Kind" Dropdown, select "Secret Text"
	6.  Under "Secret", put your AWS Access Key.
	7.  Under "ID", put "AWS_ACCESS_KEY" (without the quotes)
	8.  Repeat steps 5-8 with your secret access key as "AWS_SECRET_KEY".
	
Jenkins is taking these credentials, storing and encrypting them for use within the Jenkinsfile as environmental variables. We use these by using "withCredentials" within the pipeline during stages involving Terraform commands. Note that your Credential IDs must match the variable name for your AWS Access and Secret Keys in your variales.tf file in the Root directory, otherwise your Jenkins Pipeline will not be able to use them and thus fail. This will maintain your accounts security, hiding privileged access from the world while exposing control to the Jenkins Pipeline. This is why I similarly created a Credential variable for my `terraform.tfvars` file, passing that into the Jenkins pipeline with the"withCredentials" argument so that jenkins would have everything it needs to build the infrastructure. I suggest you do the same! 

Now, time to run the Jenkins pipeline.  My Jenkinsfile has 5 stage to it:

	1. Build Stage - This will install and build out the dependencies for both our front and backend servers, ensuring everything needed for the application to function is included in the GitHub Repo.
	2. Test Stage - Here, we conduct Django pytests on our backend application code to make sure it works properly and everything is in place for the DB migration from Sqlite.db to PostgresSQL.
	3. Init Stage - Jenkins will initialze Terraform here in the `Terraform` directory you moved into the GitHub repo.
	4. Terraform Plan - Here is the first stage where we pass along those Credentials via `withCredentials`. Jenkins will ensure it has the access and variables it needs to build out the Terraform plan.
	5. Terraform Apply - And finally, it all comes together. If your Terraform files are in order, modules properly connected, and Jenkins has all the permissions it needs, then you will have a one-click ecommerce application deployment!

Now, navigate to your Load Balancer DNS again, put it in your address bar, and if you see the ecommerce website and all the products then voila - we have successively completed our first truly automated deployment!

## Monitoring

**Why:** We need to monitor our backend servers to ensure that they aren't being overwhelmed by traffic or meddled with by bad actors. 

**How:** First, create a t3.micro for the monitoring apparatus and name it "Monitoring". It's inbound rules should allow network traffic on Ports 22 (SSH), 9000 (Prometheus), 3000 (Grafana), and allow all Outbound traffic. Choose the same VPC as your Terraform_Jenkins EC2. Next we'll set up VPC peering with the backend_servers VPC, so we can use it's private IP to scrape metrics. To set up VPC peering, follow these steps:

  1. Navigate to the VPC Dashboard and select "Peering Connections" from the left hand menu
  2. Click "Create Peering Connection"
  3. Select the Default VPC (the one Terraform/Jenkins and the Monitoring EC2 belong to) as the "Request Connection"
  4. Select the Custom VPC (the one housing the other EC2's) as the "Accepter VPC"
  5. Name it something catchy you'll remember!
  6. Go to the "Peering Connections" tab, click on your new connection, and press "Action < Accept Request"
  7. Now navigate to the "Route Tables" tab and select the Route ID for the Private Subnet in the Terraform-created VPC
  8. Click the "Routes" tab, and then "Edit Routes"
  9. Add a new route in the following page, copy the CIDR Block for the Default VPC and enter it as the 
  "Destination", select "Peering Connection" as the Target, and then choose your Peering Connection from the field dropbox below it.
 10. Go back to "Route Tables" Tab and do the same thing for the second Terraform created Private Subnet.
 11. Go back to "Route Tables" and this time select your Default VPC
 12. Follow the steps to Edit the routes for the Public Subnet and associate the Peering Connection, only this time using the CIDR Block for your Terraform VPC in the "Destinations" column.

	- Now SSH into your Monitoring EC2 and follow these steps to install and Prometheus, Grafana, and configure Prometheus to scrape metrics from both of your backend servers.

**1. Install Prometheus**:
```bash
sudo apt update
sudo apt install -y wget tar
wget https://github.com/prometheus/prometheus/releases/download/v2.36.0/prometheus-2.36.0.linux-amd64.tar.gz
tar -xvzf prometheus-2.36.0.linux-amd64.tar.gz
sudo mv prometheus-2.36.0.linux-amd64 /usr/local/prometheus
```

**2. Create a service daemon for Prometheus**:
To ensure Prometheus starts automatically:
```bash
sudo nano /etc/systemd/system/prometheus.service
```
Add the following to the file:
```bash
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/prometheus/prometheus \
--config.file=/usr/local/prometheus/prometheus.yml \
--storage.tsdb.path=/usr/local/prometheus/data
Restart=always

[Install]
WantedBy=multi-user.target
```
**3. Start and enable the service:**
```bash
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
```

**4. Install Grafana**:
Add the Grafana APT repository:
```bash
sudo apt install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add
sudo apt update
sudo apt install -y grafana
```
**5. Start and enable Grafana:**
```bash
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```

Prometheus will scrape system metrics from both of the Backend EC2's (through Node Exporter) for monitoring purposes. The `prometheus.yml` file needs to be updated to include the private IP of the both EC2 's as a target to ensure Prometheus pulls data from them. By default, Node Exporter exposes metrics on Port 9100, hence why we had to add an Inbound Rule to our Backend EC2's security group to allow traffic on Port 9100. Without this rule in place, Prometheus would be unable to collect the metrics exposed by Node Exporter. This is also why we needed to enable VPC Peering for our VPCs and add the Peering Connection to the Private Subnet Route Table - without that step, the `Monitoring` EC2 would be unable to communicate to the Private IP of the Backend EC2's. 

- **How**:
  
**1. Edit the `prometheus.yml` file**:

```bash
sudo nano /usr/local/prometheus/prometheus.yml
```

Add the following section under `scrape_configs` to target the 'Application_Server' EC2:
```bash
scrape_configs:
         - job_name: 'jenkins'
           static_configs:
             - targets: ['<Pivate_IP_of_Backend_Server1_EC2>:9100']
```
Then do the same thing to add Backend Server 2 as a target

**2. Restart Prometheus to apply the changes:**

```bash
sudo systemctl daemon-reload
sudo systemctl restart prometheus
```

---
### Add Prometheus as a Data Source in Grafana and Create Dashboards

- **Why**: Once Prometheus is scraping metrics, Grafana provides a user-friendly way to visualize the data. Creating a dashboard with graphs of system metrics (like CPU usage, memory usage, etc.) enables easy monitoring and helps track the health of the Backend EC2's in real time. This ensures that the Backend Servers operate smoothly and that any issues are quickly identified before they impact the application's performance or availability.

- **How**:
  
**1. Add Prometheus as a data source in Grafana**:
  - Open Grafana in the browser: `http://<Monitoring_Server_Public_IP>:3000`
  - Login with default credentials (`admin/admin`).
  - Navigate to **Configuration > Data Sources**, click **Add data source**, and select **Prometheus**.
  - In the **URL** field, enter: `http://localhost:9090` (since Prometheus is running locally on the Monitoring EC2).
  - Click **Save & Test**.

**2. Create a dashboard with relevant graphs**:
  - Go to **Dashboards > New Dashboard**.
  - Select **Add new panel**, and choose **Prometheus** as the data source.
  - Select "Import a Dashboard" and download this: https://grafana.com/grafana/dashboards/1860-node-exporter-full/
  - Drag the downloaded dashboard to the dropbox for Importing Dashboards
  - Save the dashboard with an appropriate name (e.g., **Backend Server Monitoring**).
---
## System Diagram

![WL5_Diagram](https://github.com/user-attachments/assets/e54edc7d-8136-4ad7-b741-2bd6b67b8520)

---
## Issues/Troubleshooting
### Issue with AWS Credentials in Jenkins for Terraform
Problem: Jenkins could not authenticate with AWS because AWS credentials weren’t correctly set up.

Solution: Added AWS Access Key and Secret Key to Jenkins Credential Manager. Referenced these credentials in the Jenkinsfile to pass them securely to Terraform commands.

**Variable Passing in Terraform**
Problem: Terraform initially failed to find the required variables, especially for the destroy command.

Solution: Specified var-file in Terraform commands and used terraform.tfvars files via Jenkins Credential Manager to standardize variable inputs across environments.

**Prometheus and Node Exporter Configurations**
Problem: Configuration issues in Prometheus, especially with incorrectly formatted prometheus.yml, led to repeated startup failures.

Solution: Debugged YAML syntax carefully, corrected indentation, and tested configurations to confirm Prometheus could successfully access backend server metrics.

**Load Balancer Target Registration**
Problem: Frontend servers were not being added to the Application Load Balancer, so I could not access the application via the ALB DNS. 

Solution: Added aws_alb_target_group_attachment resources in Terraform to attach frontend instances dynamically, ensuring they are reachable by the load balancer.

---

## Optimizations

**Optimize Load Balancer Health Checks**

I could not get the health check function for my ALB to work. I would like to Fine-tune health check intervals and thresholds to ensure efficient failover and traffic routing while reducing unnecessary health check requests that could impact performance and costs.

**Implement Auto-scaling for EC2 Instances**

Using auto-scaling policies based on CPU, memory, or network thresholds to automatically adjust the number of backend servers will make the infrastructure more resilient. This would aslo maintains availability and reduces costs by only provisioning the required resources. 

---

## Business Intelligence

Let's take a look at some of the data in our newly minted PostgreSQL DB!

```bash
	1) Row and Entries in the various tables:
ecommercedb=> SELECT COUNT (*) FROM auth_user;
 count 
-------
  3003
(1 row)

ecommercedb=> SELECT COUNT (*) FROM product_product;
 count 
-------
    33
(1 row)
                              ^
ecommercedb=> SELECT COUNT (*) FROM account_billingaddress;
 count 
-------
  3004
(1 row)

ecommercedb=> SELECT COUNT (*) FROM account_stripemodel;
 count 
-------
  3002
(1 row)

ecommercedb=> SELECT COUNT (*) FROM account_ordermodel;
 count 
-------
 15005
(1 row)
```
Now let's see which states ordered the most and the least products!

1) The top 5 states:

```bash
ecommercedb=> SELECT state, count(*) AS count
FROM account_ordermodel AS aom
INNER JOIN account_billingaddress AS aba ON aom.user_id = aba.user_id
GROUP BY state
ORDER BY count DESC
LIMIT 5;
  state  | count 
---------+-------
 Alaska  |   390
 Ohio    |   386
 Montana |   381
 Alabama |   375
 Texas   |   366
(5 rows)
```
2) THe bottom 5 states:
```bash
ecommercedb=> SELECT state, count(*) AS count
FROM account_ordermodel AS aom
INNER JOIN account_billingaddress AS aba ON aom.user_id = aba.user_id
GROUP BY state
ORDER BY count ASC
LIMIT 5;
  state   | count 
----------+-------
 ny       |     1
 unknown  |     8
 Delhi    |    16
 new york |    16
 Maine    |   224
(5 rows)
```
And let's see what products were the most sold! Here's the top 3: 
```bash
ecommercedb=> SELECT ordered_item, count(*) AS count
FROM account_ordermodel AS aom
INNER JOIN product_product AS p ON aom.ordered_item = p.name
GROUP BY ordered_item
ORDER BY count DESC
LIMIT 3;
                             ordered_item                              | count 
-----------------------------------------------------------------------+-------
 Logitech G305 Lightspeed Wireless Gaming Mouse (Various Colors)       |   502
 2TB Samsung 980 PRO M.2 PCIe Gen 4 x4 NVMe Internal Solid State Drive |   489
 Arcade1up Marvel vs Capcom Head-to-Head Arcade Table                  |   486
(3 rows)
```
The kids love their gaming mice!!

## EDR Graph

![EDR_WL5 drawio](https://github.com/user-attachments/assets/77a55097-222b-4739-8d91-1656ca7db769)





