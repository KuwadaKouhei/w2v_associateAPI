# Word2Vec API エンドポイント情報取得スクリプト
Write-Host "=== Word2Vec API エンドポイント情報 ===" -ForegroundColor Cyan
Write-Host ""

$REGION = "ap-northeast-1"
$CLUSTER_NAME = "w2v-cluster"
$SERVICE_NAME = "w2v-api-service"

# 実行中のタスクを取得
$taskArns = aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $REGION --query "taskArns" --output json | ConvertFrom-Json

if ($taskArns.Count -eq 0) {
    Write-Host "⚠️ 実行中のタスクが見つかりません" -ForegroundColor Red
    Write-Host "サービスが正常に稼働しているか確認してください:" -ForegroundColor Yellow
    Write-Host "  .\check-deployment.ps1" -ForegroundColor White
    exit
}

$taskId = ($taskArns[0] -split "/")[-1]
Write-Host "タスクID: $taskId" -ForegroundColor Green

# ネットワークインターフェースIDを取得
$networkInterfaceId = aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $taskId --region $REGION --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text

if ([string]::IsNullOrEmpty($networkInterfaceId)) {
    Write-Host "⚠️ ネットワークインターフェースIDが取得できませんでした" -ForegroundColor Red
    exit
}

Write-Host "ネットワークインターフェースID: $networkInterfaceId" -ForegroundColor Green

# パブリックIPアドレスを取得
$publicIp = aws ec2 describe-network-interfaces --network-interface-ids $networkInterfaceId --region $REGION --query "NetworkInterfaces[0].Association.PublicIp" --output text

if ([string]::IsNullOrEmpty($publicIp) -or $publicIp -eq "None") {
    Write-Host "⚠️ パブリックIPアドレスが設定されていません" -ForegroundColor Red
    Write-Host "Fargateタスクにパブリック IP が割り当てられていない可能性があります" -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "🌐 APIエンドポイント情報" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host "パブリックIP: $publicIp" -ForegroundColor White
Write-Host "ポート: 8080" -ForegroundColor White
Write-Host ""

$baseUrl = "http://${publicIp}:8080"
Write-Host "📍 利用可能なエンドポイント:" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host "ベースURL: $baseUrl" -ForegroundColor White
Write-Host ""
Write-Host "🔍 API ドキュメント (Swagger UI):" -ForegroundColor Yellow
Write-Host "  $baseUrl/docs" -ForegroundColor Blue
Write-Host ""
Write-Host "📊 代替ドキュメント (ReDoc):" -ForegroundColor Yellow  
Write-Host "  $baseUrl/redoc" -ForegroundColor Blue
Write-Host ""
Write-Host "🔧 主要エンドポイント:" -ForegroundColor Yellow
Write-Host "  GET  $baseUrl/                         # ルート - API情報" -ForegroundColor White
Write-Host "  POST $baseUrl/api/v1/associate         # 単語連想API" -ForegroundColor White
Write-Host "  GET  $baseUrl/api/v1/model/info        # モデル情報" -ForegroundColor White
Write-Host ""

Write-Host "🧪 テストコマンド例:" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "# APIが稼働しているかテスト" -ForegroundColor Cyan
Write-Host "curl $baseUrl/" -ForegroundColor Gray
Write-Host ""
Write-Host "# モデル情報の取得" -ForegroundColor Cyan
Write-Host "curl $baseUrl/api/v1/model/info" -ForegroundColor Gray
Write-Host ""
Write-Host "# 単語連想のテスト (例: '東京' の連想語、世代数2)" -ForegroundColor Cyan
Write-Host "curl -X POST `"$baseUrl/api/v1/associate`" \`" -ForegroundColor Gray
Write-Host "  -H `"Content-Type: application/json`" \`" -ForegroundColor Gray
Write-Host "  -d '{`"keyword`": `"東京`", `"generation`": 2}'" -ForegroundColor Gray
Write-Host ""
Write-Host "# より詳細な連想語取得 (世代数3、閾値指定)" -ForegroundColor Cyan
Write-Host "curl -X POST `"$baseUrl/api/v1/associate`" \`" -ForegroundColor Gray
Write-Host "  -H `"Content-Type: application/json`" \`" -ForegroundColor Gray
Write-Host "  -d '{`"keyword`": `"犬`", `"generation`": 3, `"threshold`": 0.6}'" -ForegroundColor Gray

Write-Host ""
Write-Host "📋 ブラウザでアクセス:" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host "以下のURLをブラウザで開いてAPIドキュメントを確認できます:" -ForegroundColor White
Write-Host ""
Write-Host "Swagger UIでAPIを試す:" -ForegroundColor Yellow
Write-Host "  $baseUrl/docs" -ForegroundColor Blue
Write-Host ""
Write-Host "ReDocでAPIドキュメントを見る:" -ForegroundColor Yellow
Write-Host "  $baseUrl/redoc" -ForegroundColor Blue

Write-Host ""
Write-Host "⚠️ 注意事項:" -ForegroundColor Red
Write-Host "==========" -ForegroundColor Red
Write-Host "• このパブリックIPは動的に割り当てられます" -ForegroundColor Yellow
Write-Host "• タスクを再起動するとIPアドレスが変わる可能性があります" -ForegroundColor Yellow
Write-Host "• 本格運用時はApplication Load Balancer (ALB) の使用を推奨します" -ForegroundColor Yellow

Write-Host ""
Write-Host "🔄 IPアドレスが変更された場合:" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host "このスクリプトを再実行してください:" -ForegroundColor White
Write-Host "  .\get-endpoint.ps1" -ForegroundColor Gray
