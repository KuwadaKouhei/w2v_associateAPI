#!/bin/bash

# AWS ECS Fargate Deployment Script
set -e

echo "🚀 AWS ECS Fargate デプロイ開始"

# 設定
REGION="ap-northeast-1"
CLUSTER_NAME="w2v-cluster"
SERVICE_NAME="w2v-api-service"
TASK_FAMILY="w2v-api-task"

# アカウントID取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📋 設定確認:"
echo "  アカウントID: $ACCOUNT_ID"
echo "  リージョン: $REGION"
echo "  クラスター: $CLUSTER_NAME"

# 1. タスク定義ファイルを更新
echo "📝 タスク定義を更新中..."
sed "s/ACCOUNT_ID/$ACCOUNT_ID/g" ecs-task-definition.json > ecs-task-definition-updated.json

# 2. タスク定義を登録
echo "📋 タスク定義を登録中..."
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definition-updated.json \
  --region $REGION

# 3. VPCとサブネット情報を取得
echo "🌐 ネットワーク情報を取得中..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $REGION)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region $REGION)
SUBNET_ARRAY=($(echo $SUBNET_IDS | tr ' ' '\n' | head -2))

echo "  VPC ID: $VPC_ID"
echo "  サブネット: ${SUBNET_ARRAY[0]}, ${SUBNET_ARRAY[1]}"

# 4. セキュリティグループ作成
echo "🔒 セキュリティグループを作成中..."
SG_ID=$(aws ec2 create-security-group \
  --group-name w2v-api-sg \
  --description "Security group for W2V API" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text \
  --region $REGION 2>/dev/null || \
  aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=w2v-api-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --region $REGION)

# HTTP アクセスを許可
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0 \
  --region $REGION 2>/dev/null || echo "Security group rule already exists"

echo "  セキュリティグループ ID: $SG_ID"

# 5. Application Load Balancer作成
echo "⚖️  ロードバランサーを作成中..."
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name w2v-api-alb \
  --subnets ${SUBNET_ARRAY[0]} ${SUBNET_ARRAY[1]} \
  --security-groups $SG_ID \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text \
  --region $REGION 2>/dev/null || \
  aws elbv2 describe-load-balancers \
  --names w2v-api-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text \
  --region $REGION)

# ターゲットグループ作成
TG_ARN=$(aws elbv2 create-target-group \
  --name w2v-api-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-path /api/v1/health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 10 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text \
  --region $REGION 2>/dev/null || \
  aws elbv2 describe-target-groups \
  --names w2v-api-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text \
  --region $REGION)

# リスナー作成
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $REGION 2>/dev/null || echo "Listener already exists"

# 6. ECSサービス作成
echo "🏃 ECSサービスを作成中..."

# サービス定義JSON作成
cat > service-definition.json << EOF
{
  "serviceName": "$SERVICE_NAME",
  "cluster": "$CLUSTER_NAME",
  "taskDefinition": "$TASK_FAMILY",
  "desiredCount": 2,
  "launchType": "FARGATE",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": ["${SUBNET_ARRAY[0]}", "${SUBNET_ARRAY[1]}"],
      "securityGroups": ["$SG_ID"],
      "assignPublicIp": "ENABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "$TG_ARN",
      "containerName": "w2v-api",
      "containerPort": 8080
    }
  ]
}
EOF

# サービス作成
aws ecs create-service \
  --cli-input-json file://service-definition.json \
  --region $REGION 2>/dev/null || \
  aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $TASK_FAMILY \
  --region $REGION

# 7. ロードバランサーのDNS名を取得
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text \
  --region $REGION)

echo "✅ デプロイ完了!"
echo "🌐 アクセスURL: http://$ALB_DNS"
echo "📊 API情報: http://$ALB_DNS/api/v1/model/info"
echo "📚 APIドキュメント: http://$ALB_DNS/docs"

# 一時ファイル削除
rm -f ecs-task-definition-updated.json service-definition.json

echo ""
echo "🔍 サービス状況確認:"
echo "aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION"