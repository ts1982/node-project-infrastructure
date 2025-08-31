#!/bin/bash

# EC2起動時自動デプロイスクリプト
# /etc/systemd/system/auto-deploy.service として登録

LOG_FILE="/var/log/auto-deploy.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== Auto Deploy Started: $(date) ==="

# ECR認証
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 099355342767.dkr.ecr.ap-northeast-1.amazonaws.com

# アプリケーションディレクトリに移動
cd /home/ec2-user/app

# 最新イメージをプル
/usr/local/bin/docker-compose pull

# アプリケーション起動
/usr/local/bin/docker-compose up -d

echo "=== Auto Deploy Completed: $(date) ==="
