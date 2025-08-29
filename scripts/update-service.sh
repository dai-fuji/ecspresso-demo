#!/bin/bash

# 新しいコンテナイメージでタスク定義を更新し、CodeDeployでデプロイメントを実行するスクリプト

set -e

# パラメータチェック
if [ $# -lt 1 ]; then
  echo "使用方法: $0 <new_image_uri> [task_cpu] [task_memory]"
  echo "例: $0 nginx:1.21-alpine 256 512"
  exit 1
fi

NEW_IMAGE_URI=$1
TASK_CPU=${2:-256}
TASK_MEMORY=${3:-512}

# 設定値
PROJECT_NAME="ecspresso-demo"
REGION="us-west-2"
CLUSTER_NAME="${PROJECT_NAME}-cluster"
SERVICE_NAME="${PROJECT_NAME}-service"
TASK_FAMILY="${PROJECT_NAME}-task"

echo "🚀 新しいタスク定義を作成中..."
echo "  - イメージ: $NEW_IMAGE_URI"
echo "  - CPU: $TASK_CPU"
echo "  - メモリ: $TASK_MEMORY"

# 現在のタスク定義を取得
aws ecs describe-task-definition \
  --task-definition $TASK_FAMILY \
  --region $REGION \
  --query 'taskDefinition' > current-task-def.json

# 新しいタスク定義を作成（イメージURIを更新）
jq --arg image "$NEW_IMAGE_URI" \
   --arg cpu "$TASK_CPU" \
   --arg memory "$TASK_MEMORY" \
   'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy) |
    .cpu = $cpu |
    .memory = $memory |
    .containerDefinitions[0].image = $image' \
   current-task-def.json > new-task-def.json

# 新しいタスク定義を登録
echo "📝 新しいタスク定義を登録中..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://new-task-def.json \
  --region $REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "✅ 新しいタスク定義が作成されました: $NEW_TASK_DEF_ARN"

# AppSpecファイルを作成
echo "📋 AppSpecファイルを作成中..."
cat > appspec.yaml << EOF
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "$NEW_TASK_DEF_ARN"
        LoadBalancerInfo:
          ContainerName: "${PROJECT_NAME}-container"
          ContainerPort: 80
        PlatformVersion: "LATEST"
EOF

# CodeDeployデプロイメントを実行
echo "🔄 CodeDeployデプロイメントを開始中..."
DEPLOYMENT_ID=$(aws deploy create-deployment \
  --application-name "${PROJECT_NAME}-codedeploy-app" \
  --deployment-group-name "${PROJECT_NAME}-deployment-group" \
  --revision revisionType=AppSpecContent,appSpecContent="{content='$(cat appspec.yaml | base64)'}" \
  --region $REGION \
  --query 'deploymentId' \
  --output text)

echo "🆔 デプロイメントID: $DEPLOYMENT_ID"

# デプロイメント状況を監視
echo "👀 デプロイメント状況を監視中..."
while true; do
  DEPLOYMENT_INFO=$(aws deploy get-deployment \
    --deployment-id $DEPLOYMENT_ID \
    --region $REGION \
    --query 'deploymentInfo.[status,description]' \
    --output text)
  
  STATUS=$(echo $DEPLOYMENT_INFO | cut -f1)
  DESCRIPTION=$(echo $DEPLOYMENT_INFO | cut -f2)
  
  echo "現在のステータス: $STATUS - $DESCRIPTION"
  
  if [ "$STATUS" = "Succeeded" ]; then
    echo "🎉 デプロイメントが成功しました！"
    break
  elif [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Stopped" ]; then
    echo "❌ デプロイメントが失敗しました。"
    
    # エラー詳細を取得
    aws deploy get-deployment \
      --deployment-id $DEPLOYMENT_ID \
      --region $REGION \
      --query 'deploymentInfo.errorInformation' \
      --output table
    
    exit 1
  fi
  
  sleep 30
done

# クリーンアップ
rm -f current-task-def.json new-task-def.json appspec.yaml

echo "✨ BlueGreenデプロイメントが完了しました！" 
