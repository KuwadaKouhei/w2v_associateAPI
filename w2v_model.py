"""
Word2Vec モデル管理クラス
モデルファイルの読み込みと連想語取得機能
"""

import os
import logging
from pathlib import Path
from typing import List, Tuple, Optional, Dict, Any
import numpy as np
from gensim.models import KeyedVectors
import asyncio
from concurrent.futures import ThreadPoolExecutor
import aiohttp
import hashlib
from datetime import datetime, timedelta
import random

from models import AssociationResult, Generation

logger = logging.getLogger(__name__)


class Word2VecModel:
    """Word2Vecモデル管理クラス"""
    
    def __init__(self, model_path: Optional[str] = None):
        self.model = None
        self.model_path = model_path
        self.executor = ThreadPoolExecutor(max_workers=2)
        self.models_dir = Path("models")
        self.models_dir.mkdir(exist_ok=True)
        
        # S3設定（環境変数から読み込み）
        bucket_name = os.getenv("S3_BUCKET", "my-w2v-models-2024")
        aws_region = os.getenv("AWS_REGION", "ap-northeast-1")
        base_url = f"https://{bucket_name}.s3.{aws_region}.amazonaws.com"
        model_url = os.getenv("MODEL_URL", f"{base_url}/models/entity_vector/entity_vector.model.bin")
        
        self.s3_config = {
            "bucket_url": base_url,
            "models": {
                "entity_vector.model.bin": {
                    "url": model_url,
                    "s3_key": "models/entity_vector/entity_vector.model.bin",
                    "local_path": "models/entity_vector.model.bin",
                    "size": 800000000,
                    "sha256": None
                }
            },
            "download": {
                "chunk_size": 8192,
                "max_retries": 3,
                "timeout_seconds": 300
            }
        }
        
    def _find_model_path(self) -> str:
        """モデルファイルパスを自動検出"""
        possible_paths = [
            "models/entity_vector.model.bin",
            "entity_vector/entity_vector.model.bin",
            "entity_vector/entity_vector.model.txt", 
            "models/entity_vector/model.bin",
            "models/entity_vector/model.txt"
        ]
        
        for path in possible_paths:
            if Path(path).exists():
                logger.info(f"モデルファイルを発見: {path}")
                return path
        
        return None
    
    async def load_model(self) -> bool:
        """非同期でモデルを読み込み（S3からダウンロード含む）"""
        try:
            # モデルパスが指定されていない場合は自動検出
            if not self.model_path:
                self.model_path = self._find_model_path()
            
            # ローカルにモデルが存在しない場合はS3からダウンロード
            if not self.model_path or not Path(self.model_path).exists():
                logger.info("ローカルにモデルが見つかりません。S3からダウンロードします...")
                if not await self._download_model_from_s3():
                    logger.error("S3からのモデルダウンロードに失敗しました")
                    return False
                
                # ダウンロード後のパスを設定
                self.model_path = "models/entity_vector.model.bin"
            
            logger.info(f"モデル読み込み開始: {self.model_path}")
            
            # CPUバウンドなタスクを別スレッドで実行
            loop = asyncio.get_event_loop()
            self.model = await loop.run_in_executor(
                self.executor, 
                self._load_model_sync
            )
            
            logger.info(f"モデル読み込み完了 - 語彙数: {len(self.model.key_to_index)}")
            return True
            
        except Exception as e:
            logger.error(f"モデル読み込みエラー: {e}")
            return False
    
    def _load_model_sync(self) -> KeyedVectors:
        """同期的にモデルを読み込み"""
        try:
            # バイナリ形式を試行
            if self.model_path.endswith('.bin'):
                return KeyedVectors.load_word2vec_format(
                    self.model_path, 
                    binary=True
                )
            # テキスト形式を試行
            else:
                return KeyedVectors.load_word2vec_format(
                    self.model_path, 
                    binary=False
                )
        except Exception as e:
            logger.warning(f"Word2Vec形式での読み込み失敗: {e}")
            # Gensim独自形式を試行
            return KeyedVectors.load(self.model_path)
    
    def is_loaded(self) -> bool:
        """モデルが読み込まれているかチェック"""
        return self.model is not None
    
    def get_model_info(self) -> Dict[str, Any]:
        """モデル情報を取得"""
        if not self.is_loaded():
            raise RuntimeError("モデルが読み込まれていません")
        
        return {
            "vocabulary_size": len(self.model.key_to_index),
            "vector_dimension": self.model.vector_size,
            "model_type": "word2vec"
        }
    
    def contains_word(self, word: str) -> bool:
        """単語がモデルに含まれているかチェック"""
        if not self.is_loaded():
            return False
        return word in self.model.key_to_index
    
    async def get_similar_words(
        self, 
        word: str, 
        topn: int = 10, 
        threshold: float = 0.0
    ) -> List[AssociationResult]:
        """類似語を非同期で取得"""
        if not self.is_loaded():
            raise RuntimeError("モデルが読み込まれていません")
        
        if not self.contains_word(word):
            return []
        
        try:
            # CPUバウンドなタスクを別スレッドで実行
            loop = asyncio.get_event_loop()
            similar_words = await loop.run_in_executor(
                self.executor,
                self._get_similar_words_sync,
                word, topn, threshold
            )
            
            return [
                AssociationResult(word=w, similarity=float(s))
                for w, s in similar_words
            ]
            
        except Exception as e:
            logger.error(f"類似語取得エラー - {word}: {e}")
            return []
    
    def _clean_word(self, word: str) -> str:
        """単語から括弧を除去"""
        return word.replace('[', '').replace(']', '')
    
    def _get_similar_words_sync(
        self, 
        word: str, 
        topn: int, 
        threshold: float
    ) -> List[Tuple[str, float]]:
        """同期的に類似語を取得"""
        try:
            # より多くの候補を取得してランダム性を確保
            candidate_multiplier = 4  # 指定数の4倍の候補を取得
            similar = self.model.most_similar(word, topn=topn * candidate_multiplier)
            
            # 閾値でフィルタリングと括弧除去
            filtered = [
                (self._clean_word(w), s) for w, s in similar 
                if s >= threshold
            ]
            
            # フィルタリング後の候補から指定数をランダムに選択
            if len(filtered) <= topn:
                return filtered
            else:
                return random.sample(filtered, topn)
            
        except Exception as e:
            logger.error(f"類似語計算エラー: {e}")
            return []
    
    async def get_generations(
        self,
        keyword: str,
        generation: int,
        threshold: float = 0.5
    ) -> List[Generation]:
        """世代数に応じた連想語を取得"""
        if not self.contains_word(keyword):
            raise ValueError(f"キーワード '{keyword}' がモデルに存在しません")
        
        generations = []
        
        # 第2世代: 入力キーワードから6個取得
        gen2_results = await self.get_similar_words(
            keyword, 
            topn=6, 
            threshold=threshold
        )
        
        generations.append(Generation(
            generation_number=2,
            parent_word=keyword,
            results=gen2_results,
            count=len(gen2_results)
        ))
        
        # 第3世代以降: 前世代の各単語から3個ずつ取得
        current_gen_words = [r.word for r in gen2_results]
        
        for gen_num in range(3, generation + 1):
            next_gen_results = []
            
            # 前世代の各単語から連想語を取得
            for parent_word in current_gen_words:
                if self.contains_word(parent_word):
                    similar = await self.get_similar_words(
                        parent_word,
                        topn=3,
                        threshold=threshold
                    )
                    
                    if similar:
                        generations.append(Generation(
                            generation_number=gen_num,
                            parent_word=parent_word,
                            results=similar,
                            count=len(similar)
                        ))
                        
                        # 次世代の親候補として追加
                        next_gen_results.extend([r.word for r in similar])
            
            # 次の世代の親単語を更新
            current_gen_words = next_gen_results
            
            # 親単語がなくなった場合は終了
            if not current_gen_words:
                break
        
        return generations
    
    async def _download_model_from_s3(self) -> bool:
        """S3からモデルファイルをダウンロード"""
        model_info = self.s3_config["models"]["entity_vector.model.bin"]
        url = model_info["url"]
        local_path = Path(model_info["local_path"])
        local_path.parent.mkdir(parents=True, exist_ok=True)
        
        max_retries = self.s3_config["download"]["max_retries"]
        
        for attempt in range(max_retries):
            try:
                logger.info(f"S3からダウンロード開始 (試行 {attempt + 1}/{max_retries}): {url}")
                
                async with aiohttp.ClientSession(
                    timeout=aiohttp.ClientTimeout(
                        total=self.s3_config["download"]["timeout_seconds"]
                    )
                ) as session:
                    async with session.get(url) as response:
                        response.raise_for_status()
                        
                        # サイズ検証
                        content_length = int(response.headers.get('content-length', 0))
                        expected_size = model_info.get("size")
                        if expected_size and content_length != expected_size:
                            logger.warning(f"ファイルサイズが期待値と異なります: {content_length} vs {expected_size}")
                        
                        # ストリーミングダウンロード
                        with open(local_path, 'wb') as f:
                            downloaded = 0
                            chunk_size = self.s3_config["download"]["chunk_size"]
                            
                            async for chunk in response.content.iter_chunked(chunk_size):
                                f.write(chunk)
                                downloaded += len(chunk)
                                
                                # プログレス表示（10MB毎）
                                if downloaded % (1024 * 1024 * 10) == 0:
                                    if content_length > 0:
                                        progress = (downloaded / content_length) * 100
                                        logger.info(f"ダウンロード進捗: {progress:.1f}% ({downloaded:,} / {content_length:,} bytes)")
                        
                        logger.info(f"✓ モデルファイルのダウンロード完了: {local_path}")
                        return True
                        
            except Exception as e:
                logger.warning(f"ダウンロード試行 {attempt + 1}/{max_retries} 失敗: {e}")
                if attempt < max_retries - 1:
                    await asyncio.sleep(2 ** attempt)  # 指数バックオフ
                    if local_path.exists():
                        local_path.unlink()  # 不完全なファイルを削除
        
        logger.error(f"✗ S3からのダウンロードに失敗しました（全試行終了）")
        return False
    
    def __del__(self):
        """デストラクタ"""
        if hasattr(self, 'executor'):
            self.executor.shutdown(wait=False)