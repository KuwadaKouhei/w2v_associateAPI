# Word2Vec API テスト用のサンプルコマンド集
Write-Host "=== Word2Vec API テストコマンド集 ===" -ForegroundColor Cyan
Write-Host ""

# 現在のエンドポイントを取得（簡易版）
Write-Host "📡 APIエンドポイント確認:" -ForegroundColor Green
Write-Host "現在稼働中: http://35.74.249.60:8080" -ForegroundColor White
Write-Host "最新確認: .\get-endpoint.ps1" -ForegroundColor Gray
$endpoint = "http://35.74.249.60:8080"

Write-Host ""
Write-Host "🧪 テストコマンド例:" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

Write-Host ""
Write-Host "1. ルートAPI テスト:" -ForegroundColor Cyan
Write-Host "curl -s `"$endpoint/`"" -ForegroundColor Yellow

Write-Host ""
Write-Host "2. モデル情報取得:" -ForegroundColor Cyan
Write-Host "curl -s `"$endpoint/api/v1/model/info`"" -ForegroundColor Yellow

Write-Host ""
Write-Host "3. 連想語生成 (東京):" -ForegroundColor Cyan
Write-Host "curl -X POST `"$endpoint/api/v1/associate`" -H `"Content-Type: application/json`" -d '{`"keyword`": `"東京`", `"generation`": 2}'" -ForegroundColor Yellow

Write-Host ""
Write-Host "4. 連想語生成 (技術):" -ForegroundColor Cyan
Write-Host "curl -X POST `"$endpoint/api/v1/associate`" -H `"Content-Type: application/json`" -d '{`"keyword`": `"技術`", `"generation`": 1, `"max_results`": 5}'" -ForegroundColor Yellow

Write-Host ""
Write-Host "5. 連想語生成 (音楽、3世代):" -ForegroundColor Cyan
Write-Host "curl -X POST `"$endpoint/api/v1/associate`" -H `"Content-Type: application/json`" -d '{`"keyword`": `"音楽`", `"generation`": 3, `"max_results`": 8}'" -ForegroundColor Yellow

Write-Host ""
Write-Host "📋 PowerShell用（JSON整形版）:" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

Write-Host ""
Write-Host "モデル情報（整形版）:" -ForegroundColor Cyan
Write-Host "curl -s `"$endpoint/api/v1/model/info`" | ConvertFrom-Json | ConvertTo-Json -Depth 5" -ForegroundColor Yellow

Write-Host ""
Write-Host "連想語生成（整形版）:" -ForegroundColor Cyan
Write-Host "curl -s -X POST `"$endpoint/api/v1/associate`" -H `"Content-Type: application/json`" -d '{`"keyword`": `"自然`", `"generation`": 2}' | ConvertFrom-Json | ConvertTo-Json -Depth 10" -ForegroundColor Yellow

Write-Host ""
Write-Host "🌐 ブラウザでのテスト:" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host "• HTMLテストページ: api-test.html" -ForegroundColor White
Write-Host "• Swagger UI: $endpoint/docs" -ForegroundColor Blue
Write-Host "• API仕様: $endpoint/openapi.json" -ForegroundColor Blue

Write-Host ""
Write-Host "🔧 その他の便利なコマンド:" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host "• API健全性チェック: .\test-api-health.ps1" -ForegroundColor Gray
Write-Host "• デプロイメント: .\deploy-complete.ps1" -ForegroundColor Gray
Write-Host "• AWS監視: .\aws-console-guide.ps1" -ForegroundColor Gray

Write-Host ""
Write-Host "💡 使用例:" -ForegroundColor Cyan
Write-Host "以下のコマンドをコピーして実行してください:" -ForegroundColor White

Write-Host ""
Write-Host "# 基本テスト" -ForegroundColor Green
Write-Host "curl -s `"$endpoint/`" | ConvertFrom-Json" -ForegroundColor White

Write-Host ""
Write-Host "# 日本の連想語" -ForegroundColor Green
Write-Host "curl -s -X POST `"$endpoint/api/v1/associate`" -H `"Content-Type: application/json`" -d '{`"keyword`": `"日本`", `"generation`": 2}' | ConvertFrom-Json | ConvertTo-Json -Depth 10" -ForegroundColor White
