#!/bin/bash

# AWS IAM Roles Creation Script
set -e

echo "🔐 IAMロールを作成中..."

# ECS Task Execution Role
echo "📝 ECS Task Execution Role を作成中..."

# Trust policy for ECS tasks
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# ECS Task Execution Role作成
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://trust-policy.json 2>/dev/null || echo "ecsTaskExecutionRole already exists"

# 必要なポリシーをアタッチ
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# ECS Task Role (S3アクセス用)
echo "📝 ECS Task Role を作成中..."

aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document file://trust-policy.json 2>/dev/null || echo "ecsTaskRole already exists"

# S3アクセス用のカスタムポリシー
cat > s3-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-w2v-models-2024",
        "arn:aws:s3:::my-w2v-models-2024/*"
      ]
    }
  ]
}
EOF

# カスタムポリシー作成とアタッチ
aws iam create-policy \
  --policy-name W2VModelAccessPolicy \
  --policy-document file://s3-policy.json 2>/dev/null || echo "W2VModelAccessPolicy already exists"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam attach-role-policy \
  --role-name ecsTaskRole \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/W2VModelAccessPolicy

# CloudWatch Logs Group作成
echo "📊 CloudWatch Logs Group を作成中..."
aws logs create-log-group --log-group-name /ecs/w2v-api --region ap-northeast-1 2>/dev/null || echo "Log group already exists"

# 一時ファイル削除
rm -f trust-policy.json s3-policy.json

echo "✅ IAMロール作成完了!"
echo "🔑 作成されたロール:"
echo "  - ecsTaskExecutionRole"
echo "  - ecsTaskRole"