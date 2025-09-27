# 🚀 Studify Infrastructure

AWSクラウド上で動作するStudifyアプリケーションのインフラストラクチャ管理リポジトリです。

## � システム概要

### 🏗️ アーキテクチャ
- **Frontend**: CloudFront + S3 (静的ホスティング)
- **Backend**: EC2 + Docker + Node.js/Express
- **Database**: MySQL (EBS永続化)
- **CI/CD**: GitHub Actions
- **DNS**: Route53

### 🌐 アクセスURL
- **Frontend**: https://app-dev.studify.click
- **API**: https://api-dev.studify.click

## �📁 リポジトリ構成

```
├── terraform/
│   ├── envs/dev/           # 開発環境設定
│   └── modules/            # 再利用可能なTerraformモジュール
├── scripts/                # EC2起動時スクリプト
├── Makefile               # インフラ管理コマンド
└── README.md              # このファイル
```

## 🚀 クイックスタート

### 1. 前提条件
- AWS CLI 設定済み (`aws configure`)
- Terraform v1.5+ インストール
- 適切なAWS権限

### 2. 初回セットアップ
```bash
# リポジトリクローン
git clone [repository-url]
cd node-project-infrastructure

# 初期化
make dev-init

# インフラ展開
make dev-deploy
```

#### ⚠️ ステージング環境の初回セットアップ時の注意
ステージング環境では、Lambda関数のデプロイパッケージが必要です:

```bash
# ステージング環境の初回セットアップ
cd terraform/envs/stg

# Lambda zipパッケージ生成（初回のみ必要）
zip lambda_function.zip lambda/update_route53.py

# または、Makefileを使用（推奨）
make stg-build-lambda

# ステージング環境展開
make stg-apply
```

**補足**: `lambda_function.zip` はビルド生成物のため、Gitでは管理していません。

### 3. 状態確認
```bash
make dev-status
```

## 🔧 管理コマンド

### 開発環境基本コマンド
```bash
make dev-init       # 開発環境初期セットアップ
make dev-deploy     # 開発環境インフラ展開  
make dev-status     # 開発環境システム状態確認
make dev-destroy    # 開発環境インフラ削除
```

### 開発環境緊急時コマンド
```bash
make dev-restart    # 開発環境EC2再起動
make dev-logs      # 開発環境アプリケーションログ確認
```

## 🔐 セキュリティ

### アクセス制御
- **SSH無効**: セキュリティ強化のため22ポート閉鎖
- **SSM経由**: Session Manager経由でのみアクセス可能
- **HTTPS強制**: CloudFront経由の暗号化通信

### データ保護
- **EBS暗号化**: データベースファイル暗号化
- **自動スナップショット**: データ消失時の復旧機能
- **Secrets Manager**: 機密情報の安全な管理

## 📦 CI/CD パイプライン

### GitHub Actions ワークフロー
- **Backend Deploy**: `backend-deploy.yml`
  - バックエンドコード変更時にトリガー
  - ECRへのDockerイメージプッシュ
  - EC2インスタンスでの自動デプロイ

- **Frontend Deploy**: `frontend-deploy.yml` 
  - フロントエンドコード変更時にトリガー
  - S3への静的ファイルアップロード
  - CloudFrontキャッシュ無効化

## 🛠️ トラブルシューティング

### よくある問題

#### 1. APIに接続できない
```bash
make dev-status
# API状態を確認し、必要に応じて以下を実行
make dev-restart
```

#### 2. デプロイが失敗する
```bash
make dev-logs
# ログを確認してエラー原因を特定
```

#### 3. データベースの問題
- EBS永続化により、EC2再起動後もデータは保持されます
- バックアップはスナップショット機能で自動作成されます

### 緊急時対応
1. **システム全体の再起動**: `make dev-restart`
2. **ログ確認**: `make dev-logs`
3. **完全再デプロイ**: `make dev-destroy && make dev-deploy`

## 📞 サポート

問題が発生した場合は、以下を確認してください：
1. `make dev-status` でシステム状態確認
2. `make dev-logs` でエラーログ確認
3. AWS Console でリソース状態確認

## 🔄 CI/CD連携

### GitHub Actions ワークフロー

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

### ログ確認

```bash
# Terraform実行ログ
terraform plan -out=tfplan
terraform show tfplan

```
