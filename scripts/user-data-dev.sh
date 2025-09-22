#!/bin/bash

# セキュアな設定変数
AWS_REGION="${aws_region}"
AWS_ACCOUNT_ID="${aws_account_id}"
ECR_REPOSITORY="${ecr_repository_name}"
EBS_DEVICE="${ebs_device_path}"
MYSQL_DATA_DIR="${mysql_data_dir}"
EBS_WAIT_TIMEOUT=${ebs_wait_timeout}

# ログ設定
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

# パッケージインストール
yum update -y
yum install -y docker git jq e2fsprogs amazon-ssm-agent

# Docker設定
systemctl start docker
systemctl enable docker
/usr/sbin/usermod -a -G docker ec2-user

# Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install --update

# SSM Agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# EBS Volume Setup
EBS_WAIT_COUNT=0
while [ ! -e $EBS_DEVICE ]; do
    if [ $EBS_WAIT_COUNT -ge $EBS_WAIT_TIMEOUT ]; then
        exit 1
    fi
    sleep 1
    EBS_WAIT_COUNT=$((EBS_WAIT_COUNT + 1))
done

if ! blkid $EBS_DEVICE; then
    mkfs.ext4 $EBS_DEVICE
fi

mkdir -p $MYSQL_DATA_DIR
mount $EBS_DEVICE $MYSQL_DATA_DIR
echo "$EBS_DEVICE $MYSQL_DATA_DIR ext4 defaults,nofail 0 2" >> /etc/fstab

MYSQL_CONTENT=$(ls -A "$MYSQL_DATA_DIR" 2>/dev/null | grep -v "lost+found" | wc -l)
if [ "$MYSQL_CONTENT" -eq 0 ]; then
    chown -R 999:999 $MYSQL_DATA_DIR
    chmod 755 $MYSQL_DATA_DIR
    find $MYSQL_DATA_DIR -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} \; 2>/dev/null || true
else
    chown -R 999:999 $MYSQL_DATA_DIR
    chmod 755 $MYSQL_DATA_DIR
fi

# アプリディレクトリ作成
sudo -u ec2-user mkdir -p /home/ec2-user/app
sudo -u ec2-user mkdir -p /home/ec2-user/.docker

# デプロイスクリプト作成
cat > /usr/local/bin/update-compose.sh << EOF
#!/bin/bash
set -e

AWS_REGION="${aws_region}"
AWS_ACCOUNT_ID="${aws_account_id}"
ECR_REPOSITORY="${ecr_repository_name}"
APP_DIR="/home/ec2-user/app"

echo "=== Auto Deploy Service Started ==="
echo "$(date): Starting application deployment..."

# 環境変数から取得（systemdサービスで設定）
if [ -z "\$BACKEND_SECRET_ARN" ] || [ -z "\$MYSQL_SECRET_ARN" ]; then
    echo "ERROR: BACKEND_SECRET_ARN or MYSQL_SECRET_ARN not set" >&2
    exit 1
fi

echo "$(date): Retrieving secrets from AWS Secrets Manager..."
BACKEND_SECRETS=\$(aws secretsmanager get-secret-value --secret-id "\$BACKEND_SECRET_ARN" --region \$AWS_REGION --query SecretString --output text) || {
    echo "ERROR: Failed to retrieve backend secrets" >&2
    exit 1
}
MYSQL_SECRETS=\$(aws secretsmanager get-secret-value --secret-id "\$MYSQL_SECRET_ARN" --region \$AWS_REGION --query SecretString --output text) || {
    echo "ERROR: Failed to retrieve MySQL secrets" >&2
    exit 1
}

echo "$(date): Creating environment files..."
echo "\$BACKEND_SECRETS" | jq -r 'to_entries[] | "\(.key)=\(.value)"' > "\$APP_DIR/.env.backend"
echo "\$MYSQL_SECRETS" | jq -r 'to_entries[] | "\(.key)=\(.value)"' > "\$APP_DIR/.env.mysql"
chmod 600 "\$APP_DIR"/.env.*
chown ec2-user:ec2-user "\$APP_DIR"/.env.*

echo "$(date): Authenticating with ECR..."
aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin \$AWS_ACCOUNT_ID.dkr.ecr.\$AWS_REGION.amazonaws.com || {
    echo "ERROR: ECR authentication failed" >&2
    exit 1
}

echo "$(date): Stopping existing containers..."
cd "\$APP_DIR"
docker-compose down || true

echo "$(date): Pulling latest images..."
docker-compose pull || {
    echo "ERROR: Failed to pull Docker images" >&2
    exit 1
}

echo "$(date): Starting services..."
docker-compose up -d || {
    echo "ERROR: Failed to start services" >&2
    exit 1
}

echo "$(date): Waiting for services to be ready..."
sleep 30

echo "$(date): Checking service status..."
docker-compose ps

echo "$(date): Deployment completed successfully ✅"
EOF

chmod +x /usr/local/bin/update-compose.sh
chown ec2-user:ec2-user /usr/local/bin/update-compose.sh

# 環境変数設定
cat > /etc/environment << 'ENV'
AWS_REGION=${aws_region}
AWS_ACCOUNT_ID=${aws_account_id}
ECR_REPOSITORY=${ecr_repository_name}
ENV

# アプリディレクトリ作成（初期セットアップのみ）
sudo -u ec2-user mkdir -p /home/ec2-user/app
sudo -u ec2-user mkdir -p /home/ec2-user/.docker

# docker-compose.yml テンプレート作成（初期セットアップのみ）
sudo -u ec2-user cat > /home/ec2-user/app/docker-compose.yml << EOF
services:
  backend:
    image: ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repository_name}:latest
    ports:
      - "3000:3000"
    env_file:
      - .env.backend
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - app-network
    restart: unless-stopped

  mysql:
    image: mysql:8.0
    env_file:
      - .env.mysql
    volumes:
      - /var/lib/mysql:/var/lib/mysql
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

networks:
  app-network:
    driver: bridge
EOF

chown -R ec2-user:ec2-user /home/ec2-user/app

# 初回のSecrets取得とサービス起動は update-compose.sh に委譲
echo "Initial setup completed. Secrets and application startup will be handled by auto-deploy.service"

# systemdサービス設定
mkdir -p /etc/systemd/system/auto-deploy.service.d
cat > /etc/systemd/system/auto-deploy.service.d/env.conf << EOF
[Service]
Environment=BACKEND_SECRET_ARN=${backend_secret_arn}
Environment=MYSQL_SECRET_ARN=${mysql_secret_arn}
EOF

chmod 600 /etc/systemd/system/auto-deploy.service.d/env.conf

cat > /etc/systemd/system/auto-deploy.service << EOF
[Unit]
Description=Deploy Application via GitHub Actions
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user/app
Environment=HOME=/home/ec2-user
ExecStart=/usr/local/bin/update-compose.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

systemctl enable auto-deploy.service

# 初回のアプリケーションセットアップを実行
echo "Running initial application setup via auto-deploy.service..."
systemctl start auto-deploy.service
