#!/bin/bash

# Google Cloud Run deployment script
set -e

echo "🚀 Google Cloud Run デプロイ開始"

# プロジェクト設定（要変更）
PROJECT_ID="your-project-id"
REGION="asia-northeast1"
SERVICE_NAME="w2v-association-api"

echo "📋 設定確認:"
echo "  プロジェクト: $PROJECT_ID"
echo "  リージョン: $REGION"
echo "  サービス名: $SERVICE_NAME"

# プロジェクト設定
gcloud config set project $PROJECT_ID

# API有効化
echo "🔧 必要なAPIを有効化中..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com

# デプロイ実行
echo "🏗️  ビルドとデプロイを実行中..."
gcloud run deploy $SERVICE_NAME \
  --source . \
  --platform managed \
  --region $REGION \
  --memory 8Gi \
  --cpu 4 \
  --max-instances 10 \
  --min-instances 0 \
  --timeout 900 \
  --concurrency 80 \
  --allow-unauthenticated \
  --set-env-vars MODEL_TYPE=full,S3_BUCKET=my-w2v-models-2024,AWS_REGION=ap-northeast-1

echo "✅ デプロイ完了!"
echo "🌐 サービスURL:"
gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)'