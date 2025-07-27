#!/bin/bash

# Production startup script
set -e

echo "🚀 Word2Vec Association API スタートアップ"

# Environment variables with defaults
MODEL_PATH=${MODEL_PATH:-"/home/app/models"}
API_PORT=${API_PORT:-8080}
WORKERS=${WORKERS:-1}
LOG_LEVEL=${LOG_LEVEL:-"info"}

echo "📁 モデルディレクトリ: $MODEL_PATH"
echo "🌐 APIポート: $API_PORT"
echo "👥 ワーカー数: $WORKERS"

# Pre-download models (with timeout)
echo "⬇️  モデルファイルの事前ダウンロード開始"
timeout 600s python -c "
import asyncio
import sys
import os
sys.path.append('/home/app')
from deployment.model_manager import ModelManager

async def download_models():
    manager = ModelManager()
    success = await manager.ensure_models_available()
    if not success:
        print('❌ モデルダウンロード失敗')
        sys.exit(1)
    print('✅ モデル準備完了')

asyncio.run(download_models())
" || {
    echo "❌ モデルダウンロードがタイムアウトまたは失敗しました"
    exit 1
}

# Verify critical files exist
if [ ! -f "$MODEL_PATH/entity_vector/model.bin" ]; then
    echo "❌ 必須モデルファイルが見つかりません: $MODEL_PATH/entity_vector/model.bin"
    exit 1
fi

echo "✅ モデルファイル検証完了"

# Start the API server
echo "🚀 APIサーバー起動中..."

if [ "$WORKERS" -eq 1 ]; then
    # Single worker (development/small scale)
    exec uvicorn main:app \
        --host 0.0.0.0 \
        --port $API_PORT \
        --log-level $LOG_LEVEL \
        --access-log
else
    # Multiple workers (production)
    exec gunicorn main:app \
        -w $WORKERS \
        -k uvicorn.workers.UvicornWorker \
        -b 0.0.0.0:$API_PORT \
        --log-level $LOG_LEVEL \
        --access-logfile - \
        --error-logfile - \
        --preload \
        --timeout 120 \
        --keep-alive 2 \
        --max-requests 1000 \
        --max-requests-jitter 50
fi