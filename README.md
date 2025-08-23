# Studify インフラ構成

本リポジトリは **インフラ専用（IaC/CI/CD）** です。アプリケーションは別リポジトリに分離されています。

- **Frontend**: React + TypeScript（S3/CloudFront で配信）
- **Backend**: Node.js（Express + Prisma + TypeScript）

---

## ドメイン

### dev
- フロント: `app-dev.studify.click` → CloudFront → S3
- API: `api-dev.studify.click` → Route53 Aレコード（自動更新）→ EC2（Nginx → Backend）

### prod
- フロント: `app.studify.click` → CloudFront → S3
- API: `api.studify.click` → Route53 Aレコード（自動更新）→ EC2（Nginx → Backend）

👉 固定IPは使用せず、**API ドメインは EC2 起動時に Public IP を自動で Route53 に反映**します（後述）。

---

## 全体構成（要約）
```
[Frontend Repo] --build--> GitHub Actions --sync--> S3 --origin--> CloudFront --CNAME--> app(-dev).studify.click
[Backend Repo]  --build--> GitHub Actions --push--> ECR ---------pull------> EC2 (docker compose: nginx + backend + mysql)
[Infra Repo]    --IaC----> Terraform (OIDC) -----> VPC, EC2, S3, CloudFront(OAC), Route53, IAM, ECR, Secrets, SSM, DynamoDB
                                             └--> EventBridge(Scheduler) + Lambda: EC2 起動時に Route53 A を自動更新
```

---

## 環境と運用
- **OS/アーキテクチャ**: Amazon Linux 2023 / x86_64
- **ACM**: 既存証明書（us-east-1）を CloudFront に設定
- **dev**: コスト最小化。必要時に `terraform destroy`（S3/Route53/Secrets/DynamoDB は残す）
- **prod**: 夜間停止運用（00:00-08:00 インスタンス停止、朝に自動起動。Terraform リソースは保持）

---

## リポジトリ構成（infra）
```
infra/
├─ README.md (本書)
├─ .github/workflows/
│  ├─ terraform-plan-apply.yml
│  ├─ deploy-frontend-example.yml      # Frontend用サンプル（別Repo用）
│  └─ deploy-backend-example.yml       # Backend用サンプル（別Repo用）
├─ terraform/
│  ├─ backend-bootstrap/               # 初回: tfstate用 S3/DynamoDB
│  ├─ modules/
│  │  ├─ vpc/
│  │  ├─ ec2/
│  │  ├─ s3_cloudfront/
│  │  ├─ ecr/
│  │  ├─ route53/
│  │  ├─ iam_oidc/
│  │  ├─ secrets/
│  │  └─ scheduler_dns_update/         # EventBridge + Lambda
│  └─ envs/
│     ├─ dev/
│     │  ├─ main.tf
│     │  ├─ variables.tf
│     │  ├─ outputs.tf
│     │  └─ terraform.tfvars
│     └─ prod/
│        ├─ main.tf
│        ├─ variables.tf
│        ├─ outputs.tf
│        └─ terraform.tfvars
└─ files/
   ├─ user-data.sh                     # EC2 初期化スクリプト
   ├─ docker-compose.yml               # 例
   ├─ nginx/conf.d/app.conf            # 例
   └─ lambda/update_a_record.py        # 例
```

---

## 変数例（terraform/envs/dev/terraform.tfvars）
```hcl
project              = "studify"
env                  = "dev"
region               = "ap-northeast-1"
domain               = "studify.click"
frontend_subdomain   = "app-dev"
api_subdomain        = "api-dev"
acm_arn_us_east_1    = "xxxxx"
instance_type        = "t3.small"  # x86_64
key_pair_name        = null         # SSHしない運用ならnull
allowed_http_cidrs   = ["0.0.0.0/0"]
secret_names         = ["/studify/dev/backend", "/studify/dev/mysql"]
s3_frontend_bucket   = "studify-frontend-dev"
route53_zone_id      = "ZXXXXXXXXXXXXX"      # 既存 Hosted Zone ID
scheduler_timezone   = "Asia/Tokyo"
stop_time_cron       = "cron(0 0 * * ? *)"   # JST 00:00 停止
start_time_cron      = "cron(0 8 * * ? *)"   # JST 08:00 起動
record_ttl           = 60
```
※ prod も同様に `app` / `api` とバケット名を変更

---

## 主な Terraform リソース（要点）
- **VPC**: Public Subnet x1（NAT/ALB 無し）
- **EC2**: Amazon Linux 2023（x86_64）、SSM 有効、UserData で Docker/compose 設定
- **S3 + CloudFront**: OAC + バケットポリシーで S3 を CloudFront 経由のみに制限、`app(-dev).studify.click` を Alias 設定
- **ECR**: `studify-backend`（latest と git sha を併用）
- **Route53**:
  - `app(-dev).studify.click` → CloudFront
  - `api(-dev).studify.click` → Aレコード（Public IP、自動更新）
- **Secrets Manager**: `/studify/<env>/backend`, `/studify/<env>/mysql`
- **SSM**: Run Command 用ロール、Parameter Store（必要に応じて）
- **DynamoDB + S3 (tfstate)**: Terraform Backend（ロック/保存）
- **Scheduler（夜間停止/朝起動）**: EventBridge Scheduler（cron + timezone）
- **Lambda（DNS自動更新）**: EC2 起動イベントで Public IP を取得し `api(-dev)` の A レコードを更新

---

## 夜間停止運用（prod）
- **目的**: コスト削減（00:00-08:00 は EC2 を停止し、朝に自動起動）
- **方式**:
  - EventBridge Scheduler（停止）: `stop_time_cron` で `ec2:StopInstances`
  - EventBridge Scheduler（起動）: `start_time_cron` で `ec2:StartInstances`
  - EC2 起動イベント → Lambda: Public IP を取得し Route53 A レコードを更新
- **DNS 反映**:
  - A レコード TTL = 60 秒
  - 起動後 1〜2 分で切替完了
- **注意点**:
  - 停止中は API 接続不可
  - MySQL は EC2 内 Docker のため、停止→起動で同一 EBS 上のデータを継続利用

---

## フロントエンド配置
- ビルド成果物（例: `dist/`）を S3 に `aws s3 sync` でアップロード
- CloudFront は OAC で S3 を参照し、`app(-dev).studify.click` を配信
- 404 対応（SPA想定しない場合は不要）：`index.html` をデフォルトに設定

---


## Secrets 例
- `/studify/dev/backend`（JSON 推奨）
```json
{
  "NODE_ENV": "production",
  "PORT": "3000",
  "DATABASE_URL": "mysql://app:pass@mysql:3306/studify",
  "JWT_SECRET": "xxx"
}
```
- `/studify/dev/mysql`
```json
{
  "MYSQL_ROOT_PASSWORD": "...",
  "MYSQL_DATABASE": "studify",
  "MYSQL_USER": "app",
  "MYSQL_PASSWORD": "..."
}
```

---

## Route53 レコード（例）
- `app-dev.studify.click` → CloudFront（A/AAAA Alias）
- `app.studify.click` → CloudFront（A/AAAA Alias）
- `api-dev.studify.click` → A（IP、自動更新）
- `api.studify.click` → A（IP、自動更新）