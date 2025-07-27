# AWS コンソール手動IAMロール作成ガイド
Write-Host "=== AWS コンソール手動作成ガイド ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "AWSコンソールを使用してIAMロールを作成する場合は、以下の手順に従ってください：" -ForegroundColor Yellow
Write-Host ""

Write-Host "ロール 1: ecsTaskExecutionRole" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "1. AWS IAMコンソール > ロール > ロールを作成 に移動" -ForegroundColor White
Write-Host "2. 信頼されたエンティティタイプとして「AWSのサービス」を選択" -ForegroundColor White
Write-Host "3. サービスで「Elastic Container Service」を選択" -ForegroundColor White
Write-Host "4. ユースケースで「Elastic Container Service Task」を選択" -ForegroundColor White
Write-Host "5. 「次へ: アクセス許可」をクリック" -ForegroundColor White
Write-Host "6. 「AmazonECSTaskExecutionRolePolicy」を検索してアタッチ" -ForegroundColor White
Write-Host "7. 「次へ: タグ」をクリック（タグはスキップ）" -ForegroundColor White
Write-Host "8. ロール名: 'ecsTaskExecutionRole'" -ForegroundColor White
Write-Host "9. 説明: 'W2V API用のECSタスク実行ロール'" -ForegroundColor White
Write-Host "10. 「ロールを作成」をクリック" -ForegroundColor White

Write-Host ""
Write-Host "ロール 2: ecsTaskRole" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host "1. AWS IAMコンソール > ロール > ロールを作成 に移動" -ForegroundColor White
Write-Host "2. 信頼されたエンティティタイプとして「AWSのサービス」を選択" -ForegroundColor White
Write-Host "3. サービスで「Elastic Container Service」を選択" -ForegroundColor White
Write-Host "4. ユースケースで「Elastic Container Service Task」を選択" -ForegroundColor White
Write-Host "5. 「次へ: アクセス許可」をクリック" -ForegroundColor White
Write-Host "6. 「AmazonS3ReadOnlyAccess」を検索してアタッチ" -ForegroundColor White
Write-Host "7. 「次へ: タグ」をクリック（タグはスキップ）" -ForegroundColor White
Write-Host "8. ロール名: 'ecsTaskRole'" -ForegroundColor White
Write-Host "9. 説明: 'W2V API S3アクセス用のECSタスクロール'" -ForegroundColor White
Write-Host "10. 「ロールを作成」をクリック" -ForegroundColor White

Write-Host ""
Write-Host "ユーザー権限: PassRole + 確認権限" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Green
Write-Host "デプロイユーザーがこれらのロールを使用・確認できるように権限を付与します：" -ForegroundColor White
Write-Host "1. AWS IAMコンソール > ユーザー > w2v-api-user に移動" -ForegroundColor White
Write-Host "2. 「許可を追加」>「ポリシーを直接アタッチ」をクリック" -ForegroundColor White
Write-Host "3. 「ポリシーを作成」をクリック" -ForegroundColor White
Write-Host "4. JSONタブに切り替えて、以下のポリシーを貼り付け：" -ForegroundColor White

$accountId = (aws sts get-caller-identity --query Account --output text)
Write-Host ""
Write-Host "拡張ポリシー JSON（確認権限付き）:" -ForegroundColor Cyan
Write-Host @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::$accountId`:role/ecsTaskExecutionRole",
        "arn:aws:iam::$accountId`:role/ecsTaskRole"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListAttachedRolePolicies",
        "iam:GetRolePolicy"
      ],
      "Resource": [
        "arn:aws:iam::$accountId`:role/ecsTaskExecutionRole",
        "arn:aws:iam::$accountId`:role/ecsTaskRole"
      ]
    }
  ]
}
"@ -ForegroundColor Gray

Write-Host ""
Write-Host "5. ポリシー名: 'ECSRoleManagement'" -ForegroundColor White
Write-Host "6. 「ポリシーを作成」をクリック" -ForegroundColor White
Write-Host "7. ユーザー権限に戻り、新しいポリシーをアタッチ" -ForegroundColor White

Write-Host ""
Write-Host "検証:" -ForegroundColor Green
Write-Host "=============" -ForegroundColor Green
Write-Host "ロール作成後の確認方法：" -ForegroundColor White
Write-Host ""
Write-Host "方法1: AWS CLI（権限がある場合）" -ForegroundColor Cyan
Write-Host "  aws iam get-role --role-name ecsTaskExecutionRole" -ForegroundColor Gray
Write-Host "  aws iam get-role --role-name ecsTaskRole" -ForegroundColor Gray
Write-Host ""
Write-Host "方法2: 権限エラーが出る場合（AccessDenied）" -ForegroundColor Cyan
Write-Host "  ✓ AWSコンソールでロール一覧を目視確認" -ForegroundColor White
Write-Host "  ✓ デプロイメント実行で動作確認" -ForegroundColor White
Write-Host ""
Write-Host "方法3: ECSデプロイメントでテスト" -ForegroundColor Cyan
Write-Host "  .\deploy-ecs-only.ps1  # ロールが存在すれば成功" -ForegroundColor Gray

Write-Host ""
Write-Host "次のステップ:" -ForegroundColor Green
Write-Host "===========" -ForegroundColor Green
Write-Host "両方のロール作成とPassRole権限付与が完了したら：" -ForegroundColor White
Write-Host "  .\deploy-complete.ps1  # 完全デプロイ" -ForegroundColor Cyan
Write-Host "または" -ForegroundColor Yellow
Write-Host "  .\deploy-ecs-only.ps1  # IAMロール作成をスキップ" -ForegroundColor Cyan

Write-Host ""
Write-Host "🎯 コンソールリンク:" -ForegroundColor Cyan
Write-Host "IAMロール: https://console.aws.amazon.com/iam/home#/roles" -ForegroundColor Blue
Write-Host "IAMユーザー: https://console.aws.amazon.com/iam/home#/users" -ForegroundColor Blue
Write-Host "IAMポリシー: https://console.aws.amazon.com/iam/home#/policies" -ForegroundColor Blue
