#!/bin/bash

LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== EC2 Setup Started ==="

# System packages
yum update -y
yum install -y docker git jq e2fsprogs

# Docker setup
systemctl start docker
systemctl enable docker
/usr/sbin/usermod -a -G docker ec2-user

# Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install --update

# SSM Agent
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# EBS Volume Setup - MySQL データ永続化
EBS_DEVICE="/dev/nvme1n1"
MYSQL_DATA_DIR="/var/lib/mysql"

while [ ! -e $EBS_DEVICE ]; do
    echo "Waiting for EBS volume to attach..."
    sleep 5
done

# EBSボリュームがフォーマットされていない場合のみフォーマット
if ! blkid $EBS_DEVICE; then
    echo "Formatting EBS volume..."
    mkfs.ext4 $EBS_DEVICE
fi

# MySQLデータディレクトリを直接EBSボリュームにマウント
mkdir -p $MYSQL_DATA_DIR
mount $EBS_DEVICE $MYSQL_DATA_DIR

# 永続的マウント設定
echo "$EBS_DEVICE $MYSQL_DATA_DIR ext4 defaults,nofail 0 2" >> /etc/fstab

# MySQL用のオーナー設定
chown -R 999:999 $MYSQL_DATA_DIR
chmod 755 $MYSQL_DATA_DIR

# ECR authentication
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com
sudo -u ec2-user mkdir -p /home/ec2-user/.docker
sudo -u ec2-user aws ecr get-login-password --region ap-northeast-1 | sudo -u ec2-user docker login --username AWS --password-stdin 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com

# Create docker-compose.yml for ECR images with dynamic environment variables
sudo -u ec2-user mkdir -p /home/ec2-user/app

# Get secrets from AWS Secrets Manager
BACKEND_SECRET_ARN="${backend_secret_arn}"
MYSQL_SECRET_ARN="${mysql_secret_arn}"

# Get backend secrets
BACKEND_SECRETS=$(aws secretsmanager get-secret-value --secret-id "$BACKEND_SECRET_ARN" --region ap-northeast-1 --query SecretString --output text)
DATABASE_URL=$(echo "$BACKEND_SECRETS" | jq -r '.DATABASE_URL')
API_PORT=$(echo "$BACKEND_SECRETS" | jq -r '.API_PORT')
JWT_SECRET=$(echo "$BACKEND_SECRETS" | jq -r '.JWT_SECRET')
NODE_ENV=$(echo "$BACKEND_SECRETS" | jq -r '.NODE_ENV')
CORS_ORIGINS=$(echo "$BACKEND_SECRETS" | jq -r '.CORS_ORIGINS')

# Get MySQL secrets
MYSQL_SECRETS=$(aws secretsmanager get-secret-value --secret-id "$MYSQL_SECRET_ARN" --region ap-northeast-1 --query SecretString --output text)
MYSQL_ROOT_PASSWORD=$(echo "$MYSQL_SECRETS" | jq -r '.password')
MYSQL_DATABASE=$(echo "$MYSQL_SECRETS" | jq -r '.database')
MYSQL_USER=$(echo "$MYSQL_SECRETS" | jq -r '.username')
MYSQL_PASSWORD=$(echo "$MYSQL_SECRETS" | jq -r '.password')

cat > /home/ec2-user/app/docker-compose.yml << EOF
services:
  backend:
    image: 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com/studify-backend:latest
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=$DATABASE_URL
      - API_PORT=$API_PORT
      - JWT_SECRET=$JWT_SECRET
      - NODE_ENV=$NODE_ENV
      - CORS_ORIGINS=$CORS_ORIGINS
    depends_on:
      - mysql
    networks:
      - app-network

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
      MYSQL_DATABASE: $MYSQL_DATABASE
      MYSQL_USER: $MYSQL_USER
      MYSQL_PASSWORD: $MYSQL_PASSWORD
    volumes:
      - /var/lib/mysql:/var/lib/mysql  # EBSボリュームを直接マウント
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
EOF

chown -R ec2-user:ec2-user /home/ec2-user/app

# Pull and start application
cd /home/ec2-user/app
echo "=== Verifying Docker Compose Installation ==="
/usr/local/bin/docker-compose --version
echo "=== Pulling ECR Images ==="
sudo -u ec2-user /usr/local/bin/docker-compose pull
echo "=== Starting Application ==="
sudo -u ec2-user /usr/local/bin/docker-compose up -d
echo "=== Application Status ==="
sudo -u ec2-user /usr/local/bin/docker-compose ps
echo "=== Waiting for application startup ==="
sleep 10
echo "=== Testing API Health ==="
curl -f http://localhost:3000/health || echo "API health check failed - may need more startup time"

# EC2起動時自動デプロイサービス設定
cat > /etc/systemd/system/auto-deploy.service << EOF
[Unit]
Description=Auto Deploy Application on Boot
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=root
ExecStart=/bin/bash -c "
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com
cd /home/ec2-user/app

# Update docker-compose.yml with latest secrets
BACKEND_SECRET_ARN='${backend_secret_arn}'
MYSQL_SECRET_ARN='${mysql_secret_arn}'

BACKEND_SECRETS=\\\$(aws secretsmanager get-secret-value --secret-id \\\"\\\$BACKEND_SECRET_ARN\\\" --region ap-northeast-1 --query SecretString --output text)
DATABASE_URL=\\\$(echo \\\"\\\$BACKEND_SECRETS\\\" | jq -r '.DATABASE_URL')
API_PORT=\\\$(echo \\\"\\\$BACKEND_SECRETS\\\" | jq -r '.API_PORT')
JWT_SECRET=\\\$(echo \\\"\\\$BACKEND_SECRETS\\\" | jq -r '.JWT_SECRET')
NODE_ENV=\\\$(echo \\\"\\\$BACKEND_SECRETS\\\" | jq -r '.NODE_ENV')
CORS_ORIGINS=\\\$(echo \\\"\\\$BACKEND_SECRETS\\\" | jq -r '.CORS_ORIGINS')

MYSQL_SECRETS=\\\$(aws secretsmanager get-secret-value --secret-id \\\"\\\$MYSQL_SECRET_ARN\\\" --region ap-northeast-1 --query SecretString --output text)
MYSQL_ROOT_PASSWORD=\\\$(echo \\\"\\\$MYSQL_SECRETS\\\" | jq -r '.password')
MYSQL_DATABASE=\\\$(echo \\\"\\\$MYSQL_SECRETS\\\" | jq -r '.database')
MYSQL_USER=\\\$(echo \\\"\\\$MYSQL_SECRETS\\\" | jq -r '.username')
MYSQL_PASSWORD=\\\$(echo \\\"\\\$MYSQL_SECRETS\\\" | jq -r '.password')

cat > /home/ec2-user/app/docker-compose.yml << COMPOSE_EOF
services:
  backend:
    image: 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com/studify-backend:latest
    ports:
      - \\\"3000:3000\\\"
    environment:
      - DATABASE_URL=\\\$DATABASE_URL
      - API_PORT=\\\$API_PORT
      - JWT_SECRET=\\\$JWT_SECRET
      - NODE_ENV=\\\$NODE_ENV
      - CORS_ORIGINS=\\\$CORS_ORIGINS
    depends_on:
      - mysql
    networks:
      - app-network

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: \\\$MYSQL_ROOT_PASSWORD
      MYSQL_DATABASE: \\\$MYSQL_DATABASE
      MYSQL_USER: \\\$MYSQL_USER
      MYSQL_PASSWORD: \\\$MYSQL_PASSWORD
    volumes:
      - /var/lib/mysql:/var/lib/mysql
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
COMPOSE_EOF

chown -R ec2-user:ec2-user /home/ec2-user/app
/usr/local/bin/docker-compose pull
/usr/local/bin/docker-compose up -d
"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable auto-deploy.service

# ECRイメージが存在する場合、アプリケーションを起動
echo "=== Checking for ECR Images ==="
aws ecr describe-images --repository-name studify-backend --region ap-northeast-1 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "=== ECR Images Found - Starting Application ==="
    cd /home/ec2-user/app
    sudo -u ec2-user /usr/local/bin/docker-compose pull && \
    sudo -u ec2-user /usr/local/bin/docker-compose up -d
    echo "=== Application Started ==="
else
    echo "=== No ECR Images Found - Application will start when images are pushed ==="
fi

echo "=== EC2 Setup Completed ==="
