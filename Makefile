# Studify Infrastructure Management

# Variables
LOCAL_TERRAFORM_DIR := terraform/envs/local
DEV_TERRAFORM_DIR := terraform/envs/dev
STG_TERRAFORM_DIR := terraform/envs/stg
PROD_TERRAFORM_DIR := terraform/envs/prod

# Default target
.PHONY: help
help:
	@echo "=== Studify Infrastructure Management ==="
	@echo ""
	@echo "Development Environment:"
	@echo "  make dev-init       - Initialize development environment"
	@echo "  make dev-apply      - Deploy development infrastructure"
	@echo "  make dev-status     - Check development status"
	@echo "  make dev-destroy    - Destroy development infrastructure"
	@echo "  make dev-restart    - Restart development EC2 instance"
	@echo "  make dev-logs       - View development logs"
	@echo ""
	@echo "Staging Environment:"
	@echo "  make stg-init       - Initialize staging environment"
	@echo "  make stg-apply      - Deploy staging infrastructure"
	@echo "  make stg-status     - Check staging status"
	@echo "  make stg-destroy    - Destroy staging infrastructure"
	@echo "  make stg-restart    - Restart staging ECS service"
	@echo "  make stg-logs       - View staging logs"
	@echo ""

# Development Environment
.PHONY: dev-init
dev-init:
	@echo "Initializing development environment..."
	cd $(DEV_TERRAFORM_DIR) && terraform init && terraform plan

.PHONY: dev-apply
dev-apply:
	@echo "Deploying development infrastructure..."
	cd $(DEV_TERRAFORM_DIR) && terraform apply -auto-approve

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

# Staging Environment
.PHONY: stg-init
stg-init:
	@echo "Initializing staging environment..."
	cd $(STG_TERRAFORM_DIR) && terraform init && terraform plan -var-file=terraform.tfvars

# Build Lambda deployment package
.PHONY: stg-build-lambda
stg-build-lambda:
	@echo "Building Lambda deployment package..."
	cd $(STG_TERRAFORM_DIR) && \
	if [ ! -f lambda_function.zip ]; then \
		echo "Creating lambda_function.zip from lambda/update_route53.py"; \
		zip lambda_function.zip lambda/update_route53.py; \
		echo "Lambda package created successfully"; \
	else \
		echo "lambda_function.zip already exists"; \
	fi

.PHONY: stg-apply
stg-apply: stg-build-lambda
	@echo "Deploying staging infrastructure..."
	cd $(STG_TERRAFORM_DIR) && terraform apply -auto-approve -var-file=terraform.tfvars

.PHONY: stg-status
stg-status:
	@echo "Checking staging environment status..."
	$(eval CLUSTER_NAME := $(shell cd $(STG_TERRAFORM_DIR) && terraform output -raw ecs_cluster_name 2>/dev/null || echo ""))
	$(eval SERVICE_NAME := $(shell cd $(STG_TERRAFORM_DIR) && terraform output -raw ecs_service_name 2>/dev/null || echo ""))
	@if [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Staging infrastructure not deployed. Run 'make stg-apply' first."; \
	else \
		echo "ECS Cluster: $(CLUSTER_NAME)"; \
		echo "ECS Service: $(SERVICE_NAME)"; \
		aws ecs describe-services --cluster $(CLUSTER_NAME) --services $(SERVICE_NAME) \
			--query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount,PendingCount:pendingCount}' \
			--output table 2>/dev/null || echo "Failed to get ECS service info"; \
	fi

.PHONY: stg-destroy
stg-destroy:
	@echo "Destroying staging infrastructure..."
	@echo "WARNING: This will delete all staging resources"
	@read -p "Are you sure? [y/N]: " confirm && [ "$$confirm" = "y" ]
	cd $(STG_TERRAFORM_DIR) && terraform destroy -auto-approve

.PHONY: stg-restart
stg-restart:
	@echo "Restarting staging ECS service..."
	$(eval CLUSTER_NAME := $(shell cd $(STG_TERRAFORM_DIR) && terraform output -raw ecs_cluster_name))
	$(eval SERVICE_NAME := $(shell cd $(STG_TERRAFORM_DIR) && terraform output -raw ecs_service_name))
	aws ecs update-service --cluster $(CLUSTER_NAME) --service $(SERVICE_NAME) --force-new-deployment
	@echo "ECS deployment initiated"

.PHONY: stg-logs
stg-logs:
	@echo "Viewing staging application logs..."
	aws logs tail /aws/ecs/studify-stg --follow --since 10m || echo "Failed to access CloudWatch Logs"

# Advanced State Management
.PHONY: stg-integrity-check
stg-integrity-check:
	@echo "=== State Integrity Check ==="
	@./scripts/state-integrity-check.sh

.PHONY: stg-repair
stg-repair: stg-integrity-check
	@echo "=== Staging State Repair and Sync ==="
	@echo "🔧 Checking for drift and repairing state..."
	@cd $(STG_TERRAFORM_DIR) && \
	if [ -f errored.tfstate ]; then \
		echo "⚠️  errored.tfstate detected - attempting state recovery..."; \
		echo "🚨 Manual intervention required for state fork"; \
		exit 1; \
	fi; \
	echo "🔄 Step 1: Refresh state from AWS..."; \
	terraform apply -refresh-only -auto-approve -var-file=terraform.tfvars; \
	echo "🔍 Step 2: Check for configuration drift..."; \
	terraform plan -detailed-exitcode -var-file=terraform.tfvars; \
	EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -eq 2 ]; then \
		echo "⚠️  Configuration drift detected, repairing..."; \
		terraform apply -auto-approve -var-file=terraform.tfvars && echo "✅ State repaired successfully"; \
	elif [ $$EXIT_CODE -eq 1 ]; then \
		echo "❌ Error during drift check"; \
		exit 1; \
	else \
		echo "✅ No drift detected - state is synchronized"; \
	fi; \
	echo "🔍 Step 3: Verify critical IAM policies..."; \
	aws iam list-attached-role-policies --role-name studify-stg-github-actions-backend --query 'AttachedPolicies[0].PolicyName' --output text | grep -q "studify-stg-github-actions-backend" && echo "✅ GitHub Actions IAM policy attached" || echo "❌ GitHub Actions IAM policy missing"

.PHONY: stg-validate
stg-validate:
	@echo "=== Complete Staging Environment Validation ==="
	@$(MAKE) stg-health
	@$(MAKE) stg-repair
	@echo "🧪 Testing IAM permissions..."
	@aws sts get-caller-identity > /dev/null && echo "✅ AWS CLI access working" || echo "❌ AWS CLI access failed"
	@echo "✅ Staging environment validation complete"

.PHONY: stg-health  
stg-health:
	@echo "=== Staging Environment Health Check ==="
	@echo "🔍 Checking critical resources..."
	@cd $(STG_TERRAFORM_DIR) && terraform state list | grep -E "(ecs|autoscaling|route53)" | head -10
	@echo ""
	@echo "🔐 IAM Role Status:"
	@aws iam get-role --role-name studify-stg-github-actions-backend --query 'Role.RoleName' --output text 2>/dev/null || echo "❌ Backend role missing"
	@echo "✅ Backend role exists" 2>/dev/null
	@aws iam get-role --role-name studify-stg-github-actions-infra-admin --query 'Role.RoleName' --output text 2>/dev/null || echo "❌ Admin role missing"  
	@echo "✅ Admin role exists" 2>/dev/null
