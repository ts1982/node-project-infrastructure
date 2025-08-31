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

# EBS Volume Setup
EBS_DEVICE="/dev/nvme1n1"
MOUNT_POINT="/var/lib/docker-data"

while [ ! -e $EBS_DEVICE ]; do
    sleep 5
done

if ! blkid $EBS_DEVICE; then
    mkfs.ext4 $EBS_DEVICE
fi

mkdir -p $MOUNT_POINT
mount $EBS_DEVICE $MOUNT_POINT
echo "$EBS_DEVICE $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab

mkdir -p $MOUNT_POINT/mysql-data
chown -R 999:999 $MOUNT_POINT/mysql-data

# ECR authentication
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com
sudo -u ec2-user mkdir -p /home/ec2-user/.docker
sudo -u ec2-user aws ecr get-login-password --region ap-northeast-1 | sudo -u ec2-user docker login --username AWS --password-stdin 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com

# Create docker-compose.yml for ECR images
sudo -u ec2-user mkdir -p /home/ec2-user/app
cat > /home/ec2-user/app/docker-compose.yml << 'EOF'
services:
  backend:
    image: 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com/studify-backend:latest
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=mysql://user:password@mysql:3306/todoapp
    depends_on:
      - mysql
    networks:
      - app-network

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: todoapp
      MYSQL_USER: user
      MYSQL_PASSWORD: password
    volumes:
      - /var/lib/docker-data/mysql-data:/var/lib/mysql
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

echo "=== EC2 Setup Completed ==="
