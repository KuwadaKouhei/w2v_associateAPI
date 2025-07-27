"""
Word Association API
FastAPIを使用したWord2Vec連想語APIサーバー
"""

import os
import logging
import asyncio
from contextlib import asynccontextmanager
from typing import Dict, Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from models import (
    AssociationRequest, 
    AssociationResponse, 
    ModelInfoResponse,
    ErrorResponse,
    ErrorCodeEnum,
    StatusEnum
)

# Railway用は軽量版を使用
from w2v_model_light import Word2VecModelLight as Word2VecModel

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# グローバル変数
w2v_model: Word2VecModel = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """アプリケーションライフサイクル管理"""
    global w2v_model
    
    # 起動時処理
    logger.info("🚀 Word Association API 起動中...")
    
    try:
        # モデル初期化
        w2v_model = Word2VecModel()
        
        # モデル読み込み
        logger.info("📁 モデルファイルの準備を開始...")
        success = await w2v_model.load_model()
        
        if not success:
            logger.error("❌ モデルの準備に失敗しました")
            logger.error("可能な原因:")
            logger.error("- S3からのダウンロードに失敗")
            logger.error("- ネットワーク接続の問題")
            logger.error("- ファイルの破損または不正な形式")
            logger.error("- メモリ不足")
            raise RuntimeError("モデルの初期化に失敗しました")
        
        logger.info("✅ モデルの準備が完了しました")
        model_info = w2v_model.get_model_info()
        logger.info(f"📊 語彙数: {model_info['vocabulary_size']:,}")
        logger.info(f"📏 ベクトル次元: {model_info['vector_dimension']}")
        logger.info("🎯 APIが利用可能になりました")
        
    except Exception as e:
        logger.error(f"❌ 起動エラー: {e}")
        logger.error("APIサーバーの起動に失敗しました。ログを確認してください。")
        raise
    
    yield
    
    # 終了時処理
    logger.info("⏹️  Word Association API 終了中...")


# FastAPIアプリケーション初期化
app = FastAPI(
    title="Word Association API",
    description="""
    Word2Vecベクトルモデルを使用して、入力されたキーワードから世代数に応じて連想される言葉を返すAPIです。
    
    ## 世代数システム
    - **世代数2**: 入力キーワードから6つの連想語を取得
    - **世代数3以降**: 前世代の各単語から3つずつ連想語を階層的に取得
    - 結果は世代構造として整理されて返されます
    """,
    version="1.0.0",
    contact={
        "name": "API Support",
        "email": "support@example.com"
    },
    license_info={
        "name": "MIT",
        "url": "https://opensource.org/licenses/MIT"
    },
    lifespan=lifespan
)

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切に制限
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 例外ハンドラー
@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    """ValueError例外ハンドラー"""
    return JSONResponse(
        status_code=400,
        content=ErrorResponse(
            error_code=ErrorCodeEnum.INVALID_PARAMETER,
            message=str(exc)
        ).dict()
    )


@app.exception_handler(RuntimeError)
async def runtime_error_handler(request: Request, exc: RuntimeError):
    """RuntimeError例外ハンドラー"""
    return JSONResponse(
        status_code=503,
        content=ErrorResponse(
            error_code=ErrorCodeEnum.MODEL_LOAD_ERROR,
            message=str(exc)
        ).dict()
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """一般例外ハンドラー"""
    logger.error(f"予期しないエラー: {exc}")
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error_code=ErrorCodeEnum.INTERNAL_ERROR,
            message="サーバー内部エラーが発生しました"
        ).dict()
    )


# API エンドポイント
@app.post(
    "/api/v1/associate",
    response_model=AssociationResponse,
    summary="連想語取得",
    description="""
    指定されたキーワードから世代数に応じて連想される言葉を取得します
    
    **世代数の仕組み:**
    - **世代数2**: 入力キーワードから連想語6つを取得
    - **世代数3以降**: 前世代の各単語から3つずつ連想語を取得
    
    **例:**
    - 世代数2 → 6個の連想語
    - 世代数3 → 6個 + (6×3) = 24個の連想語  
    - 世代数4 → 6個 + (6×3) + (18×3) = 78個の連想語
    """,
    responses={
        400: {"model": ErrorResponse, "description": "リクエストエラー"},
        404: {"model": ErrorResponse, "description": "キーワードが見つからない"},
        500: {"model": ErrorResponse, "description": "サーバーエラー"},
        503: {"model": ErrorResponse, "description": "サービス利用不可"}
    },
    tags=["Association"]
)
async def get_associated_words(request: AssociationRequest) -> AssociationResponse:
    """連想語取得エンドポイント"""
    global w2v_model
    
    # モデル可用性チェック
    if not w2v_model or not w2v_model.is_loaded():
        raise HTTPException(
            status_code=503,
            detail="モデルが利用できません"
        )
    
    # キーワード存在チェック
    if not w2v_model.contains_word(request.keyword):
        raise HTTPException(
            status_code=404,
            detail=f"キーワード '{request.keyword}' がモデルに存在しません"
        )
    
    try:
        # 世代別連想語取得
        logger.info(f"連想語取得開始 - キーワード: {request.keyword}, 世代数: {request.generation}")
        
        generations = await w2v_model.get_generations(
            keyword=request.keyword,
            generation=request.generation,
            threshold=request.threshold
        )
        
        # 総数計算
        total_count = sum(gen.count for gen in generations)
        
        logger.info(f"連想語取得完了 - 総数: {total_count}")
        
        return AssociationResponse(
            keyword=request.keyword,
            generation=request.generation,
            generations=generations,
            total_count=total_count
        )
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"連想語取得エラー: {e}")
        raise HTTPException(status_code=500, detail="連想語取得に失敗しました")


@app.get(
    "/api/v1/model/info",
    response_model=ModelInfoResponse,
    summary="モデル情報取得",
    description="使用中のWord2Vecモデルの情報を取得します",
    responses={
        500: {"model": ErrorResponse, "description": "サーバーエラー"}
    },
    tags=["Model"]
)
async def get_model_info() -> ModelInfoResponse:
    """モデル情報取得エンドポイント"""
    global w2v_model
    
    if not w2v_model or not w2v_model.is_loaded():
        raise HTTPException(
            status_code=503,
            detail="モデルが利用できません"
        )
    
    try:
        model_info = w2v_model.get_model_info()
        return ModelInfoResponse(model_info=model_info)
        
    except Exception as e:
        logger.error(f"モデル情報取得エラー: {e}")
        raise HTTPException(status_code=500, detail="モデル情報の取得に失敗しました")


# ルートエンドポイント
@app.get("/", include_in_schema=False)
async def root():
    """ルートエンドポイント"""
    return {
        "message": "Word Association API",
        "version": "1.0.0",
        "docs": "/docs",
        "openapi": "/openapi.json"
    }


# ヘルスチェックエンドポイント（Heroku用）
@app.get("/api/v1/health", include_in_schema=False)
async def health_check():
    """ヘルスチェックエンドポイント"""
    if not w2v_model or not w2v_model.is_loaded():
        return JSONResponse(
            status_code=503,
            content={"status": "unhealthy", "message": "モデルが読み込まれていません"}
        )
    return {"status": "healthy", "message": "API is running"}


# 開発サーバー起動
if __name__ == "__main__":
    port = int(os.getenv("PORT", os.getenv("API_PORT", 8080)))  # Heroku用PORTを優先
    host = os.getenv("API_HOST", "0.0.0.0")
    
    logger.info(f"🌐 サーバー起動: http://{host}:{port}")
    logger.info(f"📚 ドキュメント: http://{host}:{port}/docs")
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=False,  # 本番モード
        log_level="info"
    )