"""
Pydantic models for Word Association API
swagger.yamlの定義に基づくデータモデル
"""

from typing import List, Optional
from pydantic import BaseModel, Field
from enum import Enum


class StatusEnum(str, Enum):
    """レスポンスステータス列挙型"""
    SUCCESS = "success"
    ERROR = "error"


class ErrorCodeEnum(str, Enum):
    """エラーコード列挙型"""
    KEYWORD_NOT_FOUND = "KEYWORD_NOT_FOUND"
    INVALID_PARAMETER = "INVALID_PARAMETER"
    KEYWORD_REQUIRED = "KEYWORD_REQUIRED"
    INTERNAL_ERROR = "INTERNAL_ERROR"
    MODEL_LOAD_ERROR = "MODEL_LOAD_ERROR"
    RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED"


class AssociationRequest(BaseModel):
    """連想語取得リクエストモデル"""
    keyword: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="連想語を取得したいキーワード",
        example="犬"
    )
    generation: int = Field(
        ...,
        ge=2,
        le=5,
        description="世代数（2以上5以下）",
        example=2
    )
    threshold: Optional[float] = Field(
        default=0.5,
        ge=0.0,
        le=1.0,
        description="類似度の閾値",
        example=0.7
    )


class AssociationResult(BaseModel):
    """連想語結果モデル"""
    word: str = Field(
        ...,
        description="連想語",
        example="猫"
    )
    similarity: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="類似度スコア（0.0-1.0）",
        example=0.89
    )


class Generation(BaseModel):
    """世代モデル"""
    generation_number: int = Field(
        ...,
        ge=1,
        description="世代番号",
        example=2
    )
    parent_word: str = Field(
        ...,
        description="親となるキーワード（第1世代は入力キーワード）",
        example="犬"
    )
    results: List[AssociationResult] = Field(
        ...,
        description="この世代の連想語リスト"
    )
    count: int = Field(
        ...,
        ge=0,
        description="この世代の結果数",
        example=6
    )


class AssociationResponse(BaseModel):
    """連想語取得レスポンスモデル"""
    status: StatusEnum = Field(
        default=StatusEnum.SUCCESS,
        description="レスポンスステータス"
    )
    keyword: str = Field(
        ...,
        description="入力されたキーワード",
        example="犬"
    )
    generation: int = Field(
        ...,
        description="指定された世代数",
        example=2
    )
    generations: List[Generation] = Field(
        ...,
        description="世代ごとの連想語リスト"
    )
    total_count: int = Field(
        ...,
        ge=0,
        description="全世代の結果総数",
        example=6
    )


class ModelInfo(BaseModel):
    """モデル情報モデル"""
    vocabulary_size: int = Field(
        ...,
        description="語彙数",
        example=1015474
    )
    vector_dimension: int = Field(
        ...,
        description="ベクトル次元数",
        example=200
    )
    model_type: str = Field(
        ...,
        description="モデルタイプ",
        example="word2vec"
    )


class ModelInfoResponse(BaseModel):
    """モデル情報レスポンスモデル"""
    status: StatusEnum = Field(
        default=StatusEnum.SUCCESS,
        description="レスポンスステータス"
    )
    model_info: ModelInfo = Field(
        ...,
        description="モデル情報"
    )


class ErrorResponse(BaseModel):
    """エラーレスポンスモデル"""
    status: StatusEnum = Field(
        default=StatusEnum.ERROR,
        description="レスポンスステータス"
    )
    error_code: ErrorCodeEnum = Field(
        ...,
        description="エラーコード"
    )
    message: str = Field(
        ...,
        description="エラーメッセージ",
        example="指定されたキーワードがモデルに存在しません"
    )