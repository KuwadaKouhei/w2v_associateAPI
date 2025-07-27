#!/usr/bin/env python3
"""
Word Association API テストスクリプト
APIの動作確認用
"""

import asyncio
import json
import sys
from pathlib import Path

import httpx
import pytest


class APITester:
    """APIテスタークラス"""
    
    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def test_model_info(self) -> bool:
        """モデル情報取得テスト"""
        print("🔍 モデル情報取得テスト...")
        
        try:
            response = await self.client.get(f"{self.base_url}/api/v1/model/info")
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ モデル情報取得成功")
                print(f"   語彙数: {data['model_info']['vocabulary_size']:,}")
                print(f"   ベクトル次元: {data['model_info']['vector_dimension']}")
                print(f"   モデルタイプ: {data['model_info']['model_type']}")
                return True
            else:
                print(f"❌ モデル情報取得失敗: {response.status_code}")
                print(f"   レスポンス: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ モデル情報取得エラー: {e}")
            return False
    
    async def test_association_generation_2(self) -> bool:
        """世代数2の連想語取得テスト"""
        print("\n🔗 世代数2連想語取得テスト...")
        
        request_data = {
            "keyword": "犬",
            "generation": 2,
            "threshold": 0.5
        }
        
        try:
            response = await self.client.post(
                f"{self.base_url}/api/v1/associate",
                json=request_data
            )
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ 世代数2取得成功")
                print(f"   キーワード: {data['keyword']}")
                print(f"   世代数: {data['generation']}")
                print(f"   総数: {data['total_count']}")
                
                # 第2世代の結果表示
                for gen in data['generations']:
                    if gen['generation_number'] == 2:
                        print(f"   第2世代 ({gen['count']}個):")
                        for result in gen['results'][:3]:  # 最初の3個だけ表示
                            print(f"     - {result['word']} ({result['similarity']:.3f})")
                        break
                
                return True
            else:
                print(f"❌ 世代数2取得失敗: {response.status_code}")
                print(f"   レスポンス: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ 世代数2取得エラー: {e}")
            return False
    
    async def test_association_generation_3(self) -> bool:
        """世代数3の連想語取得テスト"""
        print("\n🌳 世代数3連想語取得テスト...")
        
        request_data = {
            "keyword": "犬",
            "generation": 3,
            "threshold": 0.6
        }
        
        try:
            response = await self.client.post(
                f"{self.base_url}/api/v1/associate",
                json=request_data
            )
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ 世代数3取得成功")
                print(f"   キーワード: {data['keyword']}")
                print(f"   世代数: {data['generation']}")
                print(f"   総数: {data['total_count']}")
                
                # 世代別結果表示
                gen2_count = 0
                gen3_count = 0
                
                for gen in data['generations']:
                    if gen['generation_number'] == 2:
                        gen2_count += gen['count']
                    elif gen['generation_number'] == 3:
                        gen3_count += gen['count']
                        # 最初の1つの第3世代だけ詳細表示
                        if gen3_count == gen['count']:  # 最初の第3世代
                            print(f"   第3世代例 - 親: {gen['parent_word']} ({gen['count']}個):")
                            for result in gen['results']:
                                print(f"     - {result['word']} ({result['similarity']:.3f})")
                
                print(f"   第2世代: {gen2_count}個, 第3世代: {gen3_count}個")
                return True
            else:
                print(f"❌ 世代数3取得失敗: {response.status_code}")
                print(f"   レスポンス: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ 世代数3取得エラー: {e}")
            return False
    
    async def test_error_cases(self) -> bool:
        """エラーケーステスト"""
        print("\n⚠️  エラーケーステスト...")
        
        test_cases = [
            {
                "name": "存在しないキーワード",
                "data": {"keyword": "存在しない単語12345", "generation": 2},
                "expected_status": 404
            },
            {
                "name": "無効な世代数（小さすぎ）",
                "data": {"keyword": "犬", "generation": 1},
                "expected_status": 422
            },
            {
                "name": "無効な世代数（大きすぎ）",
                "data": {"keyword": "犬", "generation": 10},
                "expected_status": 422
            },
            {
                "name": "無効な閾値",
                "data": {"keyword": "犬", "generation": 2, "threshold": 1.5},
                "expected_status": 422
            }
        ]
        
        success_count = 0
        
        for test_case in test_cases:
            try:
                response = await self.client.post(
                    f"{self.base_url}/api/v1/associate",
                    json=test_case["data"]
                )
                
                if response.status_code == test_case["expected_status"]:
                    print(f"   ✅ {test_case['name']}: 期待通りのエラー ({response.status_code})")
                    success_count += 1
                else:
                    print(f"   ❌ {test_case['name']}: 予期しないステータス ({response.status_code})")
                    
            except Exception as e:
                print(f"   ❌ {test_case['name']}: 例外発生 ({e})")
        
        return success_count == len(test_cases)
    
    async def test_performance(self) -> bool:
        """パフォーマンステスト"""
        print("\n⚡ パフォーマンステスト...")
        
        import time
        
        request_data = {
            "keyword": "犬",
            "generation": 3,
            "threshold": 0.5
        }
        
        try:
            # 複数回実行して平均時間を測定
            times = []
            
            for i in range(3):
                start_time = time.time()
                
                response = await self.client.post(
                    f"{self.base_url}/api/v1/associate",
                    json=request_data
                )
                
                end_time = time.time()
                duration = end_time - start_time
                times.append(duration)
                
                if response.status_code == 200:
                    print(f"   試行{i+1}: {duration:.2f}秒")
                else:
                    print(f"   ❌ 試行{i+1}: 失敗 ({response.status_code})")
                    return False
            
            avg_time = sum(times) / len(times)
            print(f"   平均レスポンス時間: {avg_time:.2f}秒")
            
            # 3秒以内なら成功とみなす
            return avg_time < 3.0
            
        except Exception as e:
            print(f"❌ パフォーマンステストエラー: {e}")
            return False
    
    async def run_all_tests(self) -> bool:
        """全テスト実行"""
        print("🧪 Word Association API テスト開始")
        print("=" * 50)
        
        tests = [
            ("モデル情報取得", self.test_model_info),
            ("世代数2連想語取得", self.test_association_generation_2),
            ("世代数3連想語取得", self.test_association_generation_3),
            ("エラーケース", self.test_error_cases),
            ("パフォーマンス", self.test_performance)
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            try:
                result = await test_func()
                if result:
                    passed += 1
                    print(f"✅ {test_name}: 合格")
                else:
                    print(f"❌ {test_name}: 不合格")
            except Exception as e:
                print(f"❌ {test_name}: 例外発生 - {e}")
        
        print("\n" + "=" * 50)
        print(f"🎯 テスト結果: {passed}/{total} 合格")
        
        if passed == total:
            print("🎉 全テスト合格！APIは正常に動作しています。")
            return True
        else:
            print("⚠️  一部テストが失敗しました。")
            return False
    
    async def close(self):
        """クライアント終了"""
        await self.client.aclose()


async def main():
    """メイン処理"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Word Association API テスト")
    parser.add_argument("--url", default="http://localhost:8080", help="API URL")
    args = parser.parse_args()
    
    tester = APITester(args.url)
    
    try:
        success = await tester.run_all_tests()
        return 0 if success else 1
    finally:
        await tester.close()


if __name__ == "__main__":
    exit_code = asyncio.run(main())