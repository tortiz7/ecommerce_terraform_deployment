pipeline {
    agent any
    environment {
        backend_dir = 'backend'
        frontend_dir = 'frontend'
        private_ip = "172.31.36.167"
        tf_vars_path = ''
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
                        npm install
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
                sh ''' 
                #!/bin/bash
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
                        script {
                            // Store TFVARS file path in global environment variable
                            tf_vars_path = "${TFVARS}"
                        }
                        sh 'terraform init'
                    }
                }
            }
        }

        stage('Plan') {
            steps {
                script {
                    echo "Using TFVARS file: ${tf_vars_path}"
                    sh 'ls -la Terraform'  // List files to confirm .tfvars presence
                }
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY', variable: 'aws_access_key'),
                    string(credentialsId: 'AWS_SECRET_KEY', variable: 'aws_secret_key')
                ]) {
                    dir('Terraform') {
                        sh '''
                        terraform plan \
                            -var-file=${tf_vars_path} \
                            -out plan.tfplan \
                            -var="aws_access_key=${aws_access_key}" \
                            -var="aws_secret_key=${aws_secret_key}"
                        '''
                    }
                }
            }
        }

        stage('Apply') {
            steps {
                dir('Terraform') {
                    sh '''
                    terraform apply \
                        -var-file=${tf_vars_path} \
                        plan.tfplan
                    '''
                }
            }
        }
    }

    post {
        always {
            echo 'Cleaning up...'
            sh 'rm -f Terraform/plan.tfplan'
        }
    }
}
