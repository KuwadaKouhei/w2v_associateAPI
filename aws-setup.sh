#!/bin/bash

# AWS ECS Fargate Setup Script
set -e

echo "🚀 AWS ECS Fargate セットアップ開始"

# 設定変数
REGION="ap-northeast-1"
CLUSTER_NAME="w2v-cluster"
SERVICE_NAME="w2v-api-service"
TASK_FAMILY="w2v-api-task"
REPO_NAME="w2v-api"

echo "📋 設定:"
echo "  リージョン: $REGION"
echo "  クラスター: $CLUSTER_NAME"
echo "  サービス: $SERVICE_NAME"

# アカウントIDを取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

echo "  ECRリポジトリ: $REPO_URI"

# 1. ECRリポジトリ作成
echo "🏗️  ECRリポジトリを作成中..."
aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION 2>/dev/null || \
aws ecr create-repository --repository-name $REPO_NAME --region $REGION

# 2. ECSクラスター作成
echo "🏗️  ECSクラスターを作成中..."
aws ecs describe-clusters --clusters $CLUSTER_NAME --region $REGION 2>/dev/null || \
aws ecs create-cluster --cluster-name $CLUSTER_NAME --region $REGION

# 3. Dockerイメージのビルドとプッシュ
echo "🏗️  Dockerイメージをビルド・プッシュ中..."

# ECRにログイン
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPO_URI

# イメージビルド
docker build -t $REPO_NAME .
docker tag $REPO_NAME:latest $REPO_URI:latest
docker push $REPO_URI:latest

echo "✅ セットアップ完了!"
echo "🎯 次のステップ: タスク定義の登録とサービスの作成"