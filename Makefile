# Studify Infrastructure Management Makefile

# Variables
DEV_TERRAFORM_DIR := terraform/envs/dev
# 将来の環境追加時:
# PROD_TERRAFORM_DIR := terraform/envs/prod
# LOCAL_TERRAFORM_DIR := terraform/envs/local

# Default target
.PHONY: help
help:
	@echo "=== Studify Infrastructure Management ==="
	@echo ""
	@echo "Development Environment Commands:"
	@echo "  make dev-init       - 開発環境初期セットアップ"
	@echo "  make dev-deploy     - 開発環境インフラ展開"
	@echo "  make dev-status     - 開発環境状態確認"
	@echo "  make dev-destroy    - 開発環境インフラ削除"
	@echo ""
	@echo "Development Emergency Commands:"
	@echo "  make dev-restart    - 開発環境EC2再起動"
	@echo "  make dev-logs       - 開発環境ログ確認"
	@echo ""

# 開発環境初期セットアップ
.PHONY: dev-init
dev-init:
	@echo "=== 開発環境初期セットアップ開始 ==="
	cd $(DEV_TERRAFORM_DIR) && \
	terraform init && \
	terraform plan
	@echo "=== セットアップ完了 - 'make dev-deploy'でインフラを展開してください ==="

# 開発環境インフラ展開
.PHONY: dev-deploy
dev-deploy:
	@echo "=== 開発環境インフラ展開開始 ==="
	cd $(DEV_TERRAFORM_DIR) && \
	terraform apply -auto-approve
	@$(MAKE) dev-status

# 開発環境システム状態確認
.PHONY: dev-status
dev-status:
	@echo "=== 開発環境システム状態確認 ==="
	$(eval INSTANCE_ID := $(shell cd $(DEV_TERRAFORM_DIR) && terraform output -raw instance_id 2>/dev/null || echo ""))
	$(eval PUBLIC_IP := $(shell cd $(DEV_TERRAFORM_DIR) && terraform output -raw instance_public_ip 2>/dev/null || echo ""))
	@if [ -z "$(INSTANCE_ID)" ]; then \
		echo "開発環境インフラが展開されていません。'make dev-deploy'を実行してください。"; \
	else \
		echo "Instance ID: $(INSTANCE_ID)"; \
		echo "Public IP: $(PUBLIC_IP)"; \
		echo ""; \
		echo "--- 開発環境アプリケーション状態 ---"; \
		echo "Frontend: https://app-dev.studify.click"; \
		echo "API: https://api-dev.studify.click/health"; \
		echo ""; \
		curl -f -m 5 https://api-dev.studify.click/health 2>/dev/null && echo "✅ API正常" || echo "❌ API異常"; \
	fi

# 開発環境インフラ削除
.PHONY: dev-destroy
dev-destroy:
	@echo "=== 開発環境インフラ削除開始 ==="
	@echo "警告: 開発環境の全てのリソースが削除されます"
	@read -p "本当に削除しますか？ [y/N]: " confirm && [ "$$confirm" = "y" ]
	cd $(DEV_TERRAFORM_DIR) && \
	terraform destroy -auto-approve

# 開発環境EC2再起動（緊急時）
.PHONY: dev-restart
dev-restart:
	@echo "=== 開発環境EC2再起動開始 ==="
	$(eval INSTANCE_ID := $(shell cd $(DEV_TERRAFORM_DIR) && terraform output -raw instance_id))
	aws ec2 reboot-instances --instance-ids $(INSTANCE_ID)
	@echo "再起動中... 60秒待機"
	@sleep 60
	@$(MAKE) dev-status

# 開発環境ログ確認（緊急時）
.PHONY: dev-logs
dev-logs:
	@echo "=== 開発環境アプリケーションログ確認 ==="
	$(eval INSTANCE_ID := $(shell cd $(DEV_TERRAFORM_DIR) && terraform output -raw instance_id))
	@echo "Backend logs:"
	aws ssm send-command \
		--instance-ids $(INSTANCE_ID) \
		--document-name "AWS-RunShellScript" \
		--parameters 'commands=["sudo docker logs app-backend-1 --tail 20"]' \
		--query 'Command.CommandId' --output text | \
	xargs -I {} aws ssm get-command-invocation --command-id {} --instance-id $(INSTANCE_ID) --query 'StandardOutputContent' --output text
