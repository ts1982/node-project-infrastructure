## 📁 リポジトリ構成

```
├── terraform/
│   ├── envs/dev/           # 開発環境設定
│   └── modules/            # 再利用可能なTerraformモジュール
├── scripts/                # EC2起動時スクリプト
└── README.md              # このファイル
```

## 🚀 セットアップ手順

### 1. 前提条件

- AWS CLI 設定済み (`aws configure`)
- Terraform v1.5+ インストール
- 適切なAWS権限（EC2、VPC、IAM、S3、CloudFront、Route53）

### 2. 初回セットアップ

```bash
cd terraform/envs/dev
terraform init
terraform plan
terraform apply
```

### 3. EC2インスタンスへのアクセス

**SSH接続は無効です。**以下の方法でアクセスしてください：

```bash
# SSM Session Manager経由
aws ssm start-session --target i-xxxxxxxxxxxxxxxx

# または、AWS Console > Systems Manager > Session Manager
```

## 🔧 設定詳細

### コスト最適化設定

- **EC2インスタンス**: t3.micro（約$8-10/月）
- **S3 + CloudFront**: 約$1-3/月
- **その他サービス**: 約$2-5/月
- **合計推定コスト**: 約$11-18/月

### セキュリティ設定

1. **SSH無効**: セキュリティ強化のため22ポート閉鎖
2. **SSMアクセス**: IAMロールベースの安全なアクセス
3. **S3プライベート**: CloudFront OAC経由のみアクセス可能
4. **OIDC認証**: GitHub Actions専用の最小権限IAMロール

## 🔄 CI/CD連携

### GitHub Actions ワークフロー

アプリケーションリポジトリ（`ts1982/node-project`）に以下のワークフローを配置：

- `/.github/workflows/frontend-deploy.yml` - フロントエンドデプロイ
- `/.github/workflows/backend-deploy.yml` - バックエンドデプロイ

### デプロイフロー

1. **フロントエンド**: `frontend/` 変更時
   - npm build → S3アップロード → CloudFrontキャッシュ無効化
2. **バックエンド**: `backend/` 変更時
   - Docker build → ECRプッシュ → EC2デプロイ

## 🌐 アクセス情報

- **フロントエンド**: https://app-dev.studify.click
- **バックエンドAPI**: https://api-dev.studify.click

## 📋 今後の開発計画

### 必要に応じて追加予定

- [ ] 本番環境構築（prod環境）
- [ ] Lambda ベースの自動起動・停止

### 本番環境への拡張

本設定は本番環境にも対応済みです：

1. **環境分離**: `terraform/envs/prod/` フォルダ作成
2. **GitHub Environments**: prod環境での承認フロー設定
3. **別AWSアカウント**: 本番用AWSアカウントでのデプロイ

### ログ確認

```bash
# Terraform実行ログ
terraform plan -out=tfplan
terraform show tfplan

```
