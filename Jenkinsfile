pipeline {
    agent any
    environment {
        backend_dir = 'backend'
        frontend_dir = 'frontend'
        private_ip = "172.31.36.167"
    }
    stages {
        stage('Build') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        sh '''#!/bin/bash
                        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                        sudo apt install -y nodejs
                        cd frontend
                        sed -i "s|http://private_ec2_ip:8000|http://${private_ip}:8000|" package.json
                        npm i
                        export NODE_OPTIONS=--openssl-legacy-provider
                        npm start &
                        '''
                    }
                }
                stage('Build Backend') {
                    steps {
                        sh '''#!/bin/bash
                        sudo add-apt-repository ppa:deadsnakes/ppa -y
                        sudo apt update -y
                        sudo apt install -y python3.9 python3.9-venv python3.9-dev python3-pip
                        python3.9 -m venv venv
                        source venv/bin/activate
                        pip install -r backend/requirements.txt
                        sed -i "s|ALLOWED_HOSTS = \\[\\]|ALLOWED_HOSTS = [\\"${private_ip}\\"]|" backend/my_project/settings.py
                        python3 backend/manage.py runserver 0.0.0.0:8000 &
                        '''
                    }
                }
            }
        }
        stage('Test') {
            steps {
                sh '''#!/bin/bash
                source venv/bin/activate
                pip install pytest-django
                python backend/manage.py makemigrations
                python backend/manage.py migrate
                pytest backend/account/tests.py --verbose --junit-xml test-reports/results.xml
                '''
            }
        }
        stage('Init') {
            steps {
                dir('Terraform') {
                    withCredentials([file(credentialsId: 'tf_vars', variable: 'TFVARS')]) {
                        sh 'terraform init'
                    }
                }
            }
        }
           stage('Terraform Destroy') {
         steps {
           withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'), 
                        string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                            dir('Terraform') {
                            withCredentials([file(credentialsId: 'tf_vars', variable: 'TFVARS')]) {
                              sh 'terraform destroy -auto-approve -var="access_key=${access_key}" -var="secret_key=${secret_key}" -var="tf_vars=${TFVARS}"' 
                            }
          }
        }
      }
        stage('Plan') {
            steps {
                withCredentials([string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'), 
                                 string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')]) {
                    dir('Terraform') {
                        withCredentials([file(credentialsId: 'tf_vars', variable: 'TFVARS')]) {
                            script {
                                sh '''
                                terraform plan -var-file=${TFVARS} -out plan.tfplan -var="aws_access_key=${aws_access_key}" -var="aws_secret_key=${aws_secret_key}"
                                '''
                            }
                        }
                    }
                }
            }
        }
        stage('Apply') {
            steps {
                dir('Terraform') {
                    withCredentials([file(credentialsId: 'tf_vars', variable: 'TFVARS')]) {
                        sh "terraform apply plan.tfplan"
                    }
                }
            }
        }
    }
}
