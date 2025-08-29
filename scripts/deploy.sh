#!/bin/bash

# CodeDeployを使用したBlueGreenデプロイメント実行スクリプト

set -e

# 設定値
PROJECT_NAME="ecspresso-demo"
REGION="us-west-2"
CLUSTER_NAME="${PROJECT_NAME}-cluster"
SERVICE_NAME="${PROJECT_NAME}-service"
CODEDEPLOY_APP_NAME="${PROJECT_NAME}-codedeploy-app"
DEPLOYMENT_GROUP_NAME="${PROJECT_NAME}-deployment-group"

# 現在のタスク定義ARNを取得
echo "現在のタスク定義ARNを取得中..."
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $REGION \
  --query 'services[0].taskDefinition' \
  --output text)

echo "現在のタスク定義ARN: $TASK_DEF_ARN"

# AppSpecファイルを作成
echo "AppSpecファイルを作成中..."
cat > appspec.yaml << EOF
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "$TASK_DEF_ARN"
        LoadBalancerInfo:
          ContainerName: "${PROJECT_NAME}-container"
          ContainerPort: 80
        PlatformVersion: "LATEST"
EOF

echo "AppSpec内容:"
cat appspec.yaml

# CodeDeployデプロイメントを作成
echo "CodeDeployデプロイメントを開始中..."
DEPLOYMENT_ID=$(aws deploy create-deployment \
  --application-name $CODEDEPLOY_APP_NAME \
  --deployment-group-name $DEPLOYMENT_GROUP_NAME \
  --revision revisionType=AppSpecContent,appSpecContent="{content='$(cat appspec.yaml | base64)'}" \
  --region $REGION \
  --query 'deploymentId' \
  --output text)

echo "デプロイメントID: $DEPLOYMENT_ID"

# デプロイメント状況を監視
echo "デプロイメント状況を監視中..."
while true; do
  STATUS=$(aws deploy get-deployment \
    --deployment-id $DEPLOYMENT_ID \
    --region $REGION \
    --query 'deploymentInfo.status' \
    --output text)
  
  echo "現在のステータス: $STATUS"
  
  if [ "$STATUS" = "Succeeded" ]; then
    echo "✅ デプロイメントが成功しました！"
    break
  elif [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Stopped" ]; then
    echo "❌ デプロイメントが失敗しました。"
    exit 1
  fi
  
  sleep 30
done

# クリーンアップ
rm -f appspec.yaml

echo "🎉 BlueGreenデプロイメントが完了しました！" 
