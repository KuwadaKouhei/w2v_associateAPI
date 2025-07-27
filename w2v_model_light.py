"""
軽量版Word2Vecモデル管理クラス（Vercel用）
メモリ使用量を最小限に抑えた版
"""

import os
import logging
from pathlib import Path
from typing import List, Tuple, Optional, Dict, Any
import asyncio
import aiohttp
import random

from models import AssociationResult, Generation

logger = logging.getLogger(__name__)


class Word2VecModelLight:
    """軽量版Word2Vecモデル管理クラス"""
    
    def __init__(self):
        self.model = None
        self.word_vectors = {}  # 辞書形式でベクトルを保存
        self.is_model_loaded = False
        
        # S3設定
        bucket_name = os.getenv("S3_BUCKET", "my-w2v-models-2024")
        aws_region = os.getenv("AWS_REGION", "ap-northeast-1")
        base_url = f"https://{bucket_name}.s3.{aws_region}.amazonaws.com"
        
        # 軽量版モデルのURL（事前に作成が必要）
        self.model_url = f"{base_url}/models/entity_vector_light.txt"
        
    async def load_model(self) -> bool:
        """軽量版モデルを読み込み"""
        try:
            logger.info("軽量版モデル読み込み開始")
            
            # 事前定義された単語リストのみを読み込み（メモリ節約）
            sample_words = await self._load_sample_vectors()
            
            if sample_words:
                self.word_vectors = sample_words
                self.is_model_loaded = True
                logger.info(f"軽量版モデル読み込み完了 - 語彙数: {len(self.word_vectors)}")
                return True
            else:
                logger.error("軽量版モデルの読み込みに失敗")
                return False
                
        except Exception as e:
            logger.error(f"モデル読み込みエラー: {e}")
            return False
    
    async def _load_sample_vectors(self) -> Dict[str, List[str]]:
        """サンプル連想語データを読み込み（実際の実装ではS3から取得）"""
        # 実際の実装では、事前に計算された連想語データをS3から取得
        # ここではサンプルデータを返す
        return {
            "犬": ["猫", "動物", "ペット", "散歩", "飼い主", "しっぽ"],
            "猫": ["犬", "動物", "ネコ", "魚", "毛玉", "ニャー"],
            "料理": ["食事", "調理", "レシピ", "食材", "キッチン", "味"],
            "音楽": ["歌", "楽器", "メロディー", "リズム", "コンサート", "アーティスト"],
            "本": ["読書", "小説", "図書館", "作家", "物語", "ページ"],
            "花": ["植物", "桜", "バラ", "香り", "庭", "美しい"],
            "車": ["自動車", "運転", "道路", "エンジン", "タイヤ", "交通"],
            "海": ["水", "波", "魚", "砂浜", "青", "塩"],
            "山": ["自然", "登山", "森", "頂上", "緑", "空気"],
            "雨": ["水", "天気", "傘", "雲", "湿気", "音"]
        }
    
    def is_loaded(self) -> bool:
        """モデルが読み込まれているかチェック"""
        return self.is_model_loaded
    
    def get_model_info(self) -> Dict[str, Any]:
        """モデル情報を取得"""
        if not self.is_loaded():
            raise RuntimeError("モデルが読み込まれていません")
        
        return {
            "vocabulary_size": len(self.word_vectors),
            "vector_dimension": 200,  # 固定値
            "model_type": "word2vec_light"
        }
    
    def contains_word(self, word: str) -> bool:
        """単語がモデルに含まれているかチェック"""
        if not self.is_loaded():
            return False
        return word in self.word_vectors
    
    async def get_similar_words(
        self, 
        word: str, 
        topn: int = 10, 
        threshold: float = 0.0
    ) -> List[AssociationResult]:
        """事前計算された類似語を取得"""
        if not self.is_loaded():
            raise RuntimeError("モデルが読み込まれていません")
        
        if not self.contains_word(word):
            return []
        
        try:
            # 事前計算された連想語を取得
            similar_words = self.word_vectors.get(word, [])
            
            # ランダムにシャッフルして多様性を確保
            if len(similar_words) > topn:
                similar_words = random.sample(similar_words, topn)
            
            # スコアはランダムに生成（実際の実装では事前計算値を使用）
            results = []
            for i, w in enumerate(similar_words):
                similarity = 0.9 - (i * 0.1)  # 降順でスコアを設定
                results.append(AssociationResult(word=w, similarity=similarity))
            
            return results
            
        except Exception as e:
            logger.error(f"類似語取得エラー - {word}: {e}")
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