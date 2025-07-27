"""
Vercel用のエントリーポイント
FastAPIアプリをVercelのサーバーレス関数として実行
"""

import sys
import os

# プロジェクトルートをパスに追加
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 軽量版モデルを使用
os.environ["USE_LIGHT_MODEL"] = "true"

from main import app

# Vercelはこのhandler関数を呼び出す
handler = app