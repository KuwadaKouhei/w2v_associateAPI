# AWS コンソールでのAPI確認ガイド
Write-Host "=== AWS コンソールでのWord2Vec API確認方法 ===" -ForegroundColor Cyan
Write-Host ""

# アカウント情報を取得
$accountId = (aws sts get-caller-identity --query Account --output text)
$region = "ap-northeast-1"

Write-Host "📊 現在のデプロイメント情報" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host "AWSアカウント: $accountId" -ForegroundColor White
Write-Host "リージョン: $region" -ForegroundColor White
Write-Host "クラスター名: w2v-cluster" -ForegroundColor White
Write-Host "サービス名: w2v-api-service" -ForegroundColor White

Write-Host ""
Write-Host "🔍 AWSコンソールでの確認箇所" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

Write-Host ""
Write-Host "1. ECS コンソール - メインダッシュボード" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "URL: https://ap-northeast-1.console.aws.amazon.com/ecs/v2/clusters" -ForegroundColor Blue
Write-Host ""
Write-Host "確認できる項目:" -ForegroundColor White
Write-Host "• クラスター一覧とステータス" -ForegroundColor Gray
Write-Host "• サービスの実行状況（Running/Desired タスク数）" -ForegroundColor Gray
Write-Host "• タスクの健全性とCPU/メモリ使用率" -ForegroundColor Gray
Write-Host "• 最新のデプロイメント状況" -ForegroundColor Gray

Write-Host ""
Write-Host "2. ECS クラスター詳細" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow
Write-Host "URL: https://ap-northeast-1.console.aws.amazon.com/ecs/v2/clusters/w2v-cluster" -ForegroundColor Blue
Write-Host ""
Write-Host "確認できる項目:" -ForegroundColor White
Write-Host "• サービス 'w2v-api-service' の詳細状況" -ForegroundColor Gray
Write-Host "• 実行中タスクの一覧とステータス" -ForegroundColor Gray
Write-Host "• ネットワーク設定とセキュリティグループ" -ForegroundColor Gray
Write-Host "• イベント履歴（エラーや再起動の記録）" -ForegroundColor Gray

Write-Host ""
Write-Host "3. ECS サービス詳細" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow
Write-Host "URL: https://ap-northeast-1.console.aws.amazon.com/ecs/v2/clusters/w2v-cluster/services/w2v-api-service" -ForegroundColor Blue
Write-Host ""
Write-Host "確認できる項目:" -ForegroundColor White
Write-Host "• サービス設定（希望タスク数、実行タスク数）" -ForegroundColor Gray
Write-Host "• デプロイメント履歴" -ForegroundColor Gray
Write-Host "• タスク定義のリビジョン情報" -ForegroundColor Gray
Write-Host "• ロードバランサーとターゲットグループ設定" -ForegroundColor Gray
Write-Host "• ログ設定とCloudWatch統合" -ForegroundColor Gray

Write-Host ""
Write-Host "4. ECS タスク詳細" -ForegroundColor Yellow
Write-Host "===============" -ForegroundColor Yellow
Write-Host "個別タスクをクリックして確認" -ForegroundColor Blue
Write-Host ""
Write-Host "確認できる項目:" -ForegroundColor White
Write-Host "• タスクの実行状態（RUNNING/STOPPED/PENDING）" -ForegroundColor Gray
Write-Host "• パブリックIPアドレス" -ForegroundColor Gray
Write-Host "• コンテナの詳細情報" -ForegroundColor Gray
Write-Host "• 環境変数の設定" -ForegroundColor Gray
Write-Host "• ネットワーク設定（VPC、サブネット、セキュリティグループ）" -ForegroundColor Gray

Write-Host ""
Write-Host "5. CloudWatch Logs" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow
Write-Host "URL: https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#logsV2:log-groups/log-group/%2Fecs%2Fw2v-api" -ForegroundColor Blue
Write-Host ""
Write-Host "確認できる項目:" -ForegroundColor White
Write-Host "• アプリケーションの起動ログ" -ForegroundColor Gray
Write-Host "• APIリクエスト/レスポンスログ" -ForegroundColor Gray
Write-Host "• エラーログとスタックトレース" -ForegroundColor Gray
Write-Host "• モデル読み込み状況" -ForegroundColor Gray
Write-Host "• リアルタイムログストリーミング" -ForegroundColor Gray

Write-Host ""
Write-Host "6. CloudWatch メトリクス" -ForegroundColor Yellow
Write-Host "=======================" -ForegroundColor Yellow
Write-Host "URL: https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#metricsV2:graph=~();search=ECS" -ForegroundColor Blue
Write-Host ""
Write-Host "確認できる項目:" -ForegroundColor White
Write-Host "• CPU使用率グラフ" -ForegroundColor Gray
Write-Host "• メモリ使用率グラフ" -ForegroundColor Gray
Write-Host "• ネットワークI/O統計" -ForegroundColor Gray
Write-Host "• タスク数の変化" -ForegroundColor Gray

Write-Host ""
Write-Host "7. ECR リポジトリ" -ForegroundColor Yellow
Write-Host "===============" -ForegroundColor Yellow
Write-Host "URL: https://ap-northeast-1.console.aws.amazon.com/ecr/repositories/w2v-api?region=ap-northeast-1" -ForegroundColor Blue
Write-Host ""
Write-Host "確認できる項目:" -ForegroundColor White
Write-Host "• Dockerイメージの一覧とタグ" -ForegroundColor Gray
Write-Host "• イメージのプッシュ履歴" -ForegroundColor Gray
Write-Host "• イメージサイズと脆弱性スキャン結果" -ForegroundColor Gray
Write-Host "• 使用中のイメージ（タスク定義で参照）" -ForegroundColor Gray

Write-Host ""
Write-Host "🎯 トラブルシューティング時の確認順序" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host "1. ECSサービス → タスク数 (Running/Desired)" -ForegroundColor White
Write-Host "2. タスク詳細 → ステータスとヘルスチェック" -ForegroundColor White
Write-Host "3. CloudWatch Logs → エラーメッセージ" -ForegroundColor White
Write-Host "4. CloudWatch Metrics → リソース使用率" -ForegroundColor White
Write-Host "5. ECR → 使用中のイメージタグ確認" -ForegroundColor White

Write-Host ""
Write-Host "⚡ クイックアクセス手順" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host "1. AWS Management Console にログイン" -ForegroundColor White
Write-Host "2. リージョンを 'アジアパシフィック（東京）ap-northeast-1' に設定" -ForegroundColor White
Write-Host "3. 検索バーで 'ECS' と入力してサービスに移動" -ForegroundColor White
Write-Host "4. クラスター 'w2v-cluster' をクリック" -ForegroundColor White
Write-Host "5. サービス 'w2v-api-service' をクリックして詳細確認" -ForegroundColor White

Write-Host ""
Write-Host "📱 モバイル/タブレット対応" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host "AWS Console Mobile アプリでも基本的な監視が可能:" -ForegroundColor White
Write-Host "• ECSサービスのステータス確認" -ForegroundColor Gray
Write-Host "• CloudWatchアラームの状態" -ForegroundColor Gray
Write-Host "• 基本的なメトリクス表示" -ForegroundColor Gray

Write-Host ""
Write-Host "🔔 アラート設定推奨" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow
Write-Host "CloudWatch アラームで以下を監視することを推奨:" -ForegroundColor White
Write-Host "• タスク数が0になった場合" -ForegroundColor Gray
Write-Host "• CPU使用率が80%を超えた場合" -ForegroundColor Gray
Write-Host "• メモリ使用率が90%を超えた場合" -ForegroundColor Gray
Write-Host "• 5xx エラーが増加した場合" -ForegroundColor Gray

Write-Host ""
Write-Host "💡 便利なTips" -ForegroundColor Cyan
Write-Host "============" -ForegroundColor Cyan
Write-Host "• ブラウザブックマークに各コンソールURLを保存" -ForegroundColor White
Write-Host "• CloudWatch ダッシュボードでメトリクスを集約表示" -ForegroundColor White
Write-Host "• AWS Mobile アプリでアラート通知を受信" -ForegroundColor White
Write-Host "• ECS Exec 機能でコンテナ内でのデバッグも可能" -ForegroundColor White
