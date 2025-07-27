# HTMLテストページ用のエンドポイント情報を提供するスクリプト
Write-Host "=== HTMLテストページ用エンドポイント取得 ===" -ForegroundColor Cyan

$REGION = "ap-northeast-1"
$CLUSTER_NAME = "w2v-cluster"
$SERVICE_NAME = "w2v-api-service"

# APIエンドポイントを取得
Write-Host "📡 現在のエンドポイントを取得中..." -ForegroundColor Yellow

$taskArns = aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $REGION --query "taskArns" --output json | ConvertFrom-Json

if ($taskArns.Count -eq 0) {
    Write-Host "❌ 実行中のタスクが見つかりません" -ForegroundColor Red
    Write-Host "デプロイメントを確認してください: .\deploy-complete.ps1" -ForegroundColor Yellow
    exit
}

$taskId = ($taskArns[0] -split "/")[-1]
$networkInterfaceId = aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $taskId --region $REGION --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text
$publicIp = aws ec2 describe-network-interfaces --network-interface-ids $networkInterfaceId --region $REGION --query "NetworkInterfaces[0].Association.PublicIp" --output text

if ([string]::IsNullOrEmpty($publicIp) -or $publicIp -eq "None") {
    Write-Host "❌ パブリックIPが取得できませんでした" -ForegroundColor Red
    exit
}

$endpoint = "http://${publicIp}:8080"

Write-Host "✅ エンドポイント取得成功" -ForegroundColor Green
Write-Host "📍 API エンドポイント: $endpoint" -ForegroundColor White

# HTMLファイル内のエンドポイントを更新
$htmlFile = "api-test.html"
if (Test-Path $htmlFile) {
    Write-Host ""
    Write-Host "🔧 HTMLファイルのエンドポイントを更新中..." -ForegroundColor Yellow
    
    $content = Get-Content $htmlFile -Raw
    $updatedContent = $content -replace "currentEndpoint = 'http://[^']+';", "currentEndpoint = '$endpoint';"
    $updatedContent | Set-Content $htmlFile -Encoding UTF8
    
    Write-Host "✅ HTMLファイル更新完了" -ForegroundColor Green
}

Write-Host ""
Write-Host "🌐 HTMLテストページの使用方法:" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "1. ブラウザで以下のファイルを開いてください:" -ForegroundColor White
Write-Host "   $(Get-Location)\api-test.html" -ForegroundColor Blue
Write-Host ""
Write-Host "2. または、以下のコマンドで自動的に開きます:" -ForegroundColor White
Write-Host "   Start-Process api-test.html" -ForegroundColor Gray
Write-Host ""
Write-Host "🎯 テスト可能な機能:" -ForegroundColor Green
Write-Host "  ✅ API接続テスト" -ForegroundColor White
Write-Host "  ✅ モデル情報取得" -ForegroundColor White
Write-Host "  ✅ 連想語生成（カスタムキーワード）" -ForegroundColor White
Write-Host "  ✅ クイックテスト（プリセットキーワード）" -ForegroundColor White
Write-Host ""
Write-Host "📖 追加情報:" -ForegroundColor Green
Write-Host "  • Swagger UI: $endpoint/docs" -ForegroundColor Blue
Write-Host "  • API Health: .\test-api-health.ps1" -ForegroundColor Gray
Write-Host "  • AWS Console: .\aws-console-guide.ps1" -ForegroundColor Gray

# 自動でHTMLファイルを開くかユーザーに確認
Write-Host ""
$choice = Read-Host "HTMLテストページを自動で開きますか？ (Y/N)"
if ($choice -eq "Y" -or $choice -eq "y" -or $choice -eq "") {
    Write-Host "🚀 ブラウザでHTMLテストページを開いています..." -ForegroundColor Green
    Start-Process $htmlFile
}
