# Studify Infrastructure Management Makefile

# Variables
TERRAFORM_DIR := terraform/envs/dev
WORKSPACE_ROOT := $(shell pwd)

# Default target
.PHONY: help
help:
	@echo "=== Studify Infrastructure Management ==="
	@echo ""
	@echo "Available commands:"
	@echo "  make ec2-recreate    - EC2インスタンスのみを再作成（EBSデータ保持）"
	@echo "  make ec2-recreate-fresh - EC2とEBSを完全再作成（データ初期化）"
	@echo "  make ec2-restart     - EC2インスタンスを停止→開始"
	@echo "  make ec2-status      - EC2とアプリケーションの状態確認"
	@echo "  make ebs-status      - EBSボリュームの状態確認"
	@echo "  make full-deploy     - 完全なインフラ展開"
	@echo "  make full-destroy    - 完全なインフラ削除"
	@echo "  make plan           - Terraform plan実行"
	@echo "  make apply          - Terraform apply実行"
	@echo ""

# EC2インスタンスのみを再作成（EBSボリューム保持）
.PHONY: ec2-recreate
ec2-recreate:
	@echo "=== EC2インスタンス再作成開始（EBSデータ保持） ==="
	@echo "EBSボリュームとデータベースデータは保持されます"
	@read -p "続行しますか？ [y/N]: " confirm && [ "$$confirm" = "y" ]
	cd $(TERRAFORM_DIR) && \
	terraform destroy -target=module.ebs.aws_volume_attachment.db_data -auto-approve && \
	terraform destroy -target=module.ec2.aws_instance.main -auto-approve && \
	terraform apply -target=module.ec2.aws_instance.main -auto-approve && \
	terraform apply -auto-approve
	@echo "=== EC2再作成完了 - EBSボリュームとデータは保持されました ==="
	@$(MAKE) ec2-status

# EC2インスタンスとEBSボリュームを完全に再作成（データ初期化）
.PHONY: ec2-recreate-fresh
ec2-recreate-fresh:
	@echo "=== EC2インスタンス完全再作成開始 ==="
	@echo "警告: EBSボリューム（データベースデータ）も削除されます"
	@read -p "データベースデータを削除してよろしいですか？ [y/N]: " confirm && [ "$$confirm" = "y" ]
	cd $(TERRAFORM_DIR) && \
	terraform destroy -target=module.ec2.aws_instance.main -auto-approve && \
	terraform apply -auto-approve
	@echo "=== EC2完全再作成完了 - 新しいuser-data.shが適用されました ==="
	@$(MAKE) ec2-status

# EBSボリュームの状態確認
.PHONY: ebs-status
ebs-status:
	@echo "=== EBSボリューム状態確認 ==="
	$(eval VOLUME_ID := $(shell cd $(TERRAFORM_DIR) && terraform output -raw ebs_volume_id 2>/dev/null || echo ""))
	@if [ -z "$(VOLUME_ID)" ]; then \
		echo "EBSボリュームが見つかりません"; \
	else \
		echo "Volume ID: $(VOLUME_ID)"; \
		aws ec2 describe-volumes --volume-ids $(VOLUME_ID) \
			--query 'Volumes[0].[State,Size,VolumeType,Encrypted,Attachments[0].InstanceId]' \
			--output table; \
	fi

# EC2インスタンスの停止→開始
.PHONY: ec2-restart
ec2-restart:
	@echo "=== EC2インスタンス再起動開始 ==="
	$(eval INSTANCE_ID := $(shell cd $(TERRAFORM_DIR) && terraform output -raw instance_id))
	aws ec2 stop-instances --instance-ids $(INSTANCE_ID)
	@echo "EC2停止中... 30秒待機"
	@sleep 30
	aws ec2 start-instances --instance-ids $(INSTANCE_ID)
	@echo "EC2開始中... 60秒待機"
	@sleep 60
	@$(MAKE) ec2-status

# EC2とアプリケーションの状態確認
.PHONY: ec2-status
ec2-status:
	@echo "=== EC2とアプリケーション状態確認 ==="
	$(eval INSTANCE_ID := $(shell cd $(TERRAFORM_DIR) && terraform output -raw instance_id))
	$(eval PUBLIC_IP := $(shell cd $(TERRAFORM_DIR) && terraform output -raw instance_public_ip))
	@echo "Instance ID: $(INSTANCE_ID)"
	@echo "Public IP: $(PUBLIC_IP)"
	@echo ""
	@echo "--- EC2状態 ---"
	aws ec2 describe-instances --instance-ids $(INSTANCE_ID) \
		--query 'Reservations[0].Instances[0].State.Name' --output text
	@echo ""
	@echo "--- Docker状態確認 ---"
	aws ssm start-session --target $(INSTANCE_ID) \
		--document-name AWS-StartInteractiveCommand \
		--parameters 'command=sudo docker ps -a' || echo "Docker確認失敗"
	@echo ""
	@echo "--- アプリケーション動作確認 ---"
	@echo "Health Check (Direct): http://$(PUBLIC_IP):3000/health"
	@curl -f -m 5 http://$(PUBLIC_IP):3000/health || echo "直接アクセス失敗"
	@echo ""
	@echo "CloudFront経由でのアクセス:"
	@echo "  Frontend: https://app-dev.studify.click"
	@echo "  API: https://api-dev.studify.click/health"

# 完全なインフラ展開
.PHONY: full-deploy
full-deploy:
	@echo "=== 完全インフラ展開開始 ==="
	cd $(TERRAFORM_DIR) && \
	terraform init && \
	terraform plan -out=tfplan && \
	terraform apply tfplan
	@$(MAKE) ec2-status

# 完全なインフラ削除
.PHONY: full-destroy
full-destroy:
	@echo "=== 完全インフラ削除開始 ==="
	@echo "警告: 全てのリソースが削除されます（EBSボリュームを含む）"
	@read -p "本当に削除しますか？ [y/N]: " confirm && [ "$$confirm" = "y" ]
	cd $(TERRAFORM_DIR) && \
	terraform destroy -auto-approve

# Terraform plan
.PHONY: plan
plan:
	@echo "=== Terraform Plan実行 ==="
	cd $(TERRAFORM_DIR) && \
	terraform plan

# Terraform apply
.PHONY: apply
apply:
	@echo "=== Terraform Apply実行 ==="
	cd $(TERRAFORM_DIR) && \
	terraform apply -auto-approve

# 緊急時: アプリケーション手動起動
.PHONY: emergency-start
emergency-start:
	@echo "=== 緊急時アプリケーション手動起動 ==="
	$(eval INSTANCE_ID := $(shell cd $(TERRAFORM_DIR) && terraform output -raw instance_id))
	aws ssm start-session --target $(INSTANCE_ID) \
		--document-name AWS-StartInteractiveCommand \
		--parameters 'command=cd /home/ec2-user/app && sudo -u ec2-user docker-compose up -d'

# ECRイメージ確認
.PHONY: ecr-status
ecr-status:
	@echo "=== ECR Repository状態確認 ==="
	aws ecr describe-images --repository-name studify-backend \
		--query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
		--output table || echo "ECRにイメージが存在しません"

# 開発用: ログ確認
.PHONY: logs
logs:
	@echo "=== アプリケーションログ確認 ==="
	$(eval INSTANCE_ID := $(shell cd $(TERRAFORM_DIR) && terraform output -raw instance_id))
	aws ssm start-session --target $(INSTANCE_ID) \
		--document-name AWS-StartInteractiveCommand \
		--parameters 'command=sudo docker logs app-backend-1 --tail 50'

# 開発用: user-data.sh ログ確認
.PHONY: user-data-logs
user-data-logs:
	@echo "=== user-data.sh ログ確認 ==="
	$(eval INSTANCE_ID := $(shell cd $(TERRAFORM_DIR) && terraform output -raw instance_id))
	aws ssm start-session --target $(INSTANCE_ID) \
		--document-name AWS-StartInteractiveCommand \
		--parameters 'command=sudo tail -50 /var/log/user-data.log'
