#!/bin/bash

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create a symlink for docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install CloudWatch agent (for monitoring)
yum install -y amazon-cloudwatch-agent

# Install SSM agent (should already be installed on Amazon Linux 2023)
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Create application directory
mkdir -p /opt/studify
chown ec2-user:ec2-user /opt/studify

# Create logs directory
mkdir -p /var/log/studify
chown ec2-user:ec2-user /var/log/studify

# Log completion
echo "User data script completed at $(date)" >> /var/log/studify/user-data.log
