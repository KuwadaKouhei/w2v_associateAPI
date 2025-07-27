# Word2Vec API 動作確認スクリプト
Write-Host "=== Word2Vec API 動作確認 ===" -ForegroundColor Cyan
Write-Host ""

# エンドポイント情報を取得
$REGION = "ap-northeast-1"
$CLUSTER_NAME = "w2v-cluster"
$SERVICE_NAME = "w2v-api-service"

Write-Host "📊 API動作状況確認中..." -ForegroundColor Yellow

# APIエンドポイントを取得
$taskArns = aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $REGION --query "taskArns" --output json | ConvertFrom-Json

if ($taskArns.Count -eq 0) {
    Write-Host "❌ 実行中のタスクが見つかりません" -ForegroundColor Red
    Write-Host "AWSコンソールで確認してください:" -ForegroundColor Yellow
    Write-Host "  https://ap-northeast-1.console.aws.amazon.com/ecs/v2/clusters/w2v-cluster/services/w2v-api-service" -ForegroundColor Blue
    exit
}

$taskId = ($taskArns[0] -split "/")[-1]
$networkInterfaceId = aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $taskId --region $REGION --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text
$publicIp = aws ec2 describe-network-interfaces --network-interface-ids $networkInterfaceId --region $REGION --query "NetworkInterfaces[0].Association.PublicIp" --output text

if ([string]::IsNullOrEmpty($publicIp) -or $publicIp -eq "None") {
    Write-Host "❌ パブリックIPが取得できませんでした" -ForegroundColor Red
    exit
}

$baseUrl = "http://${publicIp}:8080"

Write-Host "🔍 API動作テスト結果" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host "エンドポイント: $baseUrl" -ForegroundColor White
Write-Host ""

# 1. ルートエンドポイントテスト
Write-Host "1. ルートAPI テスト..." -ForegroundColor Cyan
try {
    $response = curl -s "$baseUrl/" 2>$null
    if ($response) {
        $json = $response | ConvertFrom-Json
        Write-Host "   ✅ ルートAPI: 正常" -ForegroundColor Green
        Write-Host "   📝 API名: $($json.message)" -ForegroundColor Gray
        Write-Host "   📝 バージョン: $($json.version)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ ルートAPI: 応答なし" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ ルートAPI: エラー" -ForegroundColor Red
}

# 2. モデル情報テスト
Write-Host ""
Write-Host "2. モデル情報 テスト..." -ForegroundColor Cyan
try {
    $response = curl -s "$baseUrl/api/v1/model/info" 2>$null
    if ($response) {
        $json = $response | ConvertFrom-Json
        Write-Host "   ✅ モデル情報: 正常" -ForegroundColor Green
        Write-Host "   📝 語彙数: $($json.model_info.vocabulary_size.ToString('N0'))" -ForegroundColor Gray
        Write-Host "   📝 ベクトル次元: $($json.model_info.vector_dimension)" -ForegroundColor Gray
        Write-Host "   📝 モデルタイプ: $($json.model_info.model_type)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ モデル情報: 応答なし" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ モデル情報: エラー" -ForegroundColor Red
}

# 3. 連想語APIテスト
Write-Host ""
Write-Host "3. 連想語API テスト..." -ForegroundColor Cyan
try {
    $body = '{"keyword": "東京", "generation": 2}'
    $response = curl -s -X POST "$baseUrl/api/v1/associate" -H "Content-Type: application/json" -d $body 2>$null
    if ($response) {
        $json = $response | ConvertFrom-Json
        Write-Host "   ✅ 連想語API: 正常" -ForegroundColor Green
        Write-Host "   📝 入力キーワード: $($json.keyword)" -ForegroundColor Gray
        Write-Host "   📝 世代数: $($json.generation)" -ForegroundColor Gray
        Write-Host "   📝 結果数: $($json.total_count)" -ForegroundColor Gray
        
        if ($json.generations -and $json.generations.Count -gt 0) {
            Write-Host "   📝 連想語例:" -ForegroundColor Gray
            $results = $json.generations[0].results
            for ($i = 0; $i -lt [Math]::Min(3, $results.Count); $i++) {
                $word = $results[$i].word
                $similarity = [Math]::Round($results[$i].similarity, 3)
                Write-Host "      - $word (類似度: $similarity)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "   ❌ 連想語API: 応答なし" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ 連想語API: エラー" -ForegroundColor Red
}

Write-Host ""
Write-Host "🌐 ブラウザでの確認" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host "以下のURLでSwagger UIを開いてAPIを試すことができます:" -ForegroundColor White
Write-Host "$baseUrl/docs" -ForegroundColor Blue

Write-Host ""
Write-Host "🔧 AWSコンソールでの詳細確認" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green
Write-Host "ECSサービス詳細:" -ForegroundColor White
Write-Host "  https://ap-northeast-1.console.aws.amazon.com/ecs/v2/clusters/w2v-cluster/services/w2v-api-service" -ForegroundColor Blue
Write-Host ""
Write-Host "CloudWatch ログ:" -ForegroundColor White
Write-Host "  https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#logsV2:log-groups/log-group/%2Fecs%2Fw2v-api" -ForegroundColor Blue

Write-Host ""
Write-Host "💡 このスクリプトを定期実行して API の健全性を監視できます" -ForegroundColor Cyan
