# ECS Fargate Blue/Green Deployment Demo

このプロジェクトは、ALB と ECS Fargate を利用した検証環境を Terraform で構築し、CodeDeploy を使用した BlueGreen デプロイメントを実現するデモです。

## アーキテクチャ

- **VPC**: パブリックサブネットのみ（NatGateway 不使用）
- **ALB**: Application Load Balancer
- **ECS**: Fargate 上でのコンテナ実行
- **CodeDeploy**: BlueGreen デプロイメント
- **S3**: Terraform の state 管理

## 前提条件

1. AWS CLI 設定済み
2. Terraform 1.0 以上がインストール済み
3. S3 バケットが作成済み（Terraform state 用）

## セットアップ手順

### 1. S3 バケットの作成

```bash
# Terraform state用のS3バケットを作成
aws s3 mb s3://your-terraform-state-bucket --region us-west-2
```

### 2. 設定ファイルの準備

```bash
# 設定ファイルをコピー
cp terraform.tfvars.example terraform.tfvars

# 必要に応じて値を編集
vim terraform.tfvars
```

### 3. main.tf のバックエンド設定を更新

`main.tf`の`backend "s3"`セクションで、実際の S3 バケット名を指定してください：

```hcl
backend "s3" {
  bucket = "your-actual-terraform-state-bucket"  # 実際のバケット名に変更
  key    = "ecspresso-demo/terraform.tfstate"
  region = "us-west-2"
}
```

### 4. Terraform の実行

```bash
# 初期化
terraform init

# プランの確認
terraform plan

# リソースの作成
terraform apply
```

## リソース構成

### ネットワーク

- VPC (10.0.0.0/16)
- パブリックサブネット x2 (異なる AZ)
- Internet Gateway
- Route Table

### セキュリティ

- ALB 用セキュリティグループ (HTTP/HTTPS)
- ECS タスク用セキュリティグループ (ALB からのトラフィックのみ)

### ロードバランサー

- Application Load Balancer
- ターゲットグループ (Blue/Green)
- リスナー (HTTP)

### ECS

- ECS クラスター
- タスク定義 (Fargate)
- ECS サービス (CodeDeploy 制御)

### CodeDeploy

- CodeDeploy アプリケーション
- デプロイメントグループ
- IAM ロール

## BlueGreen デプロイメント

CodeDeploy を使用した BlueGreen デプロイメントは以下の流れで実行されます：

1. 新しいタスク定義で Green 環境を作成
2. Green 環境でヘルスチェック実行
3. トラフィックを Blue から Green に切り替え
4. Blue 環境を終了

## 出力値

デプロイ完了後、以下の情報が出力されます：

- ALB DNS 名
- ECS クラスター名
- ターゲットグループ ARN

## クリーンアップ

```bash
terraform destroy
```

## 注意事項

1. 初回デプロイ時は Blue ターゲットグループにトラフィックが流れます
2. CodeDeploy でのデプロイメントは AWS CLI またはコンソールから実行します
3. NatGateway を使用しないため、コンテナはパブリック IP を持ちます
