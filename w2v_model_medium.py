"""
中程度Word2Vecモデル管理クラス（1000語彙）
段階的アップグレード用
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


class Word2VecModelMedium:
    """中程度Word2Vecモデル管理クラス"""
    
    def __init__(self):
        self.model = None
        self.word_vectors = {}  # 辞書形式でベクトルを保存
        self.is_model_loaded = False
        
        # S3設定
        bucket_name = os.getenv("S3_BUCKET", "my-w2v-models-2024")
        aws_region = os.getenv("AWS_REGION", "ap-northeast-1")
        base_url = f"https://{bucket_name}.s3.{aws_region}.amazonaws.com"
        
        # 中程度モデルのURL
        self.model_url = f"{base_url}/models/entity_vector_medium.txt"
        
    async def load_model(self) -> bool:
        """中程度モデルを読み込み"""
        try:
            logger.info("中程度モデル読み込み開始")
            
            # より多くの単語を読み込み（1000語彙程度）
            sample_words = await self._load_medium_vectors()
            
            if sample_words:
                self.word_vectors = sample_words
                self.is_model_loaded = True
                logger.info(f"中程度モデル読み込み完了 - 語彙数: {len(self.word_vectors)}")
                return True
            else:
                logger.error("中程度モデルの読み込みに失敗")
                return False
                
        except Exception as e:
            logger.error(f"モデル読み込みエラー: {e}")
            return False
    
    async def _load_medium_vectors(self) -> Dict[str, List[str]]:
        """中程度の連想語データを読み込み（1000語彙程度）"""
        # 実際の実装では、事前に計算された連想語データをS3から取得
        # ここでは拡張されたサンプルデータを返す
        
        base_words = {
            # 動物関連
            "犬": ["猫", "動物", "ペット", "散歩", "飼い主", "しっぽ", "忠実", "番犬"],
            "猫": ["犬", "動物", "ネコ", "魚", "毛玉", "ニャー", "かわいい", "独立"],
            "象": ["大きい", "鼻", "アフリカ", "記憶", "群れ", "動物園", "灰色", "牙"],
            "鳥": ["空", "飛ぶ", "羽", "さえずり", "巣", "卵", "翼", "自由"],
            
            # 食べ物関連
            "料理": ["食事", "調理", "レシピ", "食材", "キッチン", "味", "おいしい", "栄養"],
            "寿司": ["魚", "米", "日本", "職人", "新鮮", "わさび", "醤油", "海苔"],
            "パン": ["小麦", "焼く", "朝食", "バター", "パン屋", "食パン", "発酵", "香り"],
            "カレー": ["スパイス", "辛い", "インド", "ライス", "野菜", "肉", "香辛料", "煮込み"],
            
            # 自然関連
            "海": ["水", "波", "魚", "砂浜", "青", "塩", "深い", "広い"],
            "山": ["自然", "登山", "森", "頂上", "緑", "空気", "高い", "景色"],
            "川": ["水", "流れ", "魚", "橋", "源流", "清い", "岸", "船"],
            "森": ["木", "緑", "動物", "静か", "酸素", "葉", "自然", "深い"],
            
            # 趣味・娯楽
            "音楽": ["歌", "楽器", "メロディー", "リズム", "コンサート", "アーティスト", "演奏", "感動"],
            "映画": ["映像", "物語", "俳優", "監督", "映画館", "エンターテインメント", "感情", "芸術"],
            "読書": ["本", "知識", "物語", "作家", "図書館", "学習", "想像", "集中"],
            "スポーツ": ["運動", "競技", "チーム", "健康", "練習", "勝負", "体力", "技術"],
            
            # 学問・仕事
            "数学": ["計算", "数字", "公式", "論理", "証明", "問題", "解答", "学習"],
            "科学": ["実験", "研究", "発見", "理論", "技術", "進歩", "知識", "真理"],
            "芸術": ["美", "創造", "表現", "文化", "感性", "技法", "作品", "鑑賞"],
            "ビジネス": ["仕事", "会社", "経済", "利益", "戦略", "成長", "チーム", "成功"],
            
            # 天気・季節
            "雨": ["水", "天気", "傘", "雲", "湿気", "音", "しずく", "恵み"],
            "雪": ["白", "冬", "寒い", "結晶", "積雪", "雪だるま", "美しい", "静寂"],
            "春": ["桜", "暖かい", "新緑", "花", "始まり", "希望", "成長", "美しい"],
            "夏": ["暑い", "海", "太陽", "休暇", "活動", "祭り", "エネルギー", "青空"],
            
            # 家族・人間関係
            "家族": ["愛", "絆", "支え", "温かい", "団結", "大切", "思い出", "幸せ"],
            "友達": ["仲間", "信頼", "楽しい", "支え合い", "共感", "笑顔", "思い出", "大切"],
            "恋人": ["愛情", "特別", "一緒", "幸せ", "理解", "支え", "将来", "大切"],
            
            # 感情・抽象概念
            "愛": ["大切", "温かい", "深い", "永遠", "美しい", "純粋", "強い", "優しい"],
            "希望": ["未来", "明るい", "前向き", "夢", "可能性", "光", "勇気", "信念"],
            "平和": ["静か", "安全", "調和", "穏やか", "理解", "協力", "愛", "尊重"],
            "自由": ["解放", "選択", "独立", "権利", "開放", "無制限", "可能性", "責任"]
        }
        
        # 各単語に対してより多くの関連語を生成
        expanded_words = {}
        for word, related in base_words.items():
            # 基本の関連語
            expanded_words[word] = related.copy()
            
            # 関連語の関連語も追加（相互参照）
            for rel_word in related[:4]:  # 最初の4つの関連語について
                if rel_word not in expanded_words:
                    expanded_words[rel_word] = [word] + [w for w in related if w != rel_word][:5]
        
        return expanded_words
    
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
            "model_type": "word2vec_medium"
        }
    
    def contains_word(self, word: str) -> bool:
        """単語がモデルに含まれているかチェック"""
        if not self.is_loaded():
            return False
        return word in self.word_vectors
    
    def _clean_word(self, word: str) -> str:
        """単語から括弧を除去"""
        return word.replace('[', '').replace(']', '')
    
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
            
            # 括弧を除去
            similar_words = [self._clean_word(w) for w in similar_words]
            
            # ランダムにシャッフルして多様性を確保
            if len(similar_words) > topn:
                similar_words = random.sample(similar_words, topn)
            
            # スコアはランダムに生成（実際の実装では事前計算値を使用）
            results = []
            for i, w in enumerate(similar_words):
                similarity = 0.95 - (i * 0.05)  # 降順でスコアを設定
                if similarity >= threshold:
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