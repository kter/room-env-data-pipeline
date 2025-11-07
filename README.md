# Room Environment Data Pipeline

GCP Cloud FunctionsベースのWebhook受信システムです。Terraformでインフラを管理し、dev/prdの2環境に対応しています。

## システム構成

```
room-env-data-pipeline/
├── modules/
│   └── webhook-function/          # Cloud Functionsモジュール
│       ├── main.tf                # Cloud Functionsのリソース定義
│       ├── variables.tf           # モジュールの変数定義
│       ├── outputs.tf             # モジュールの出力
│       └── function-source/       # Cloud Functionのソースコード
│           ├── main.py            # Webhookハンドラー（Python）
│           └── requirements.txt   # Python依存パッケージ
├── env/
│   ├── dev/                       # 開発環境
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars       # 設定済み（room-env-data-pipeline-dev）
│   │   └── terraform.tfvars.example
│   └── prd/                       # 本番環境
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars       # 設定済み（room-env-data-pipeline）
│       └── terraform.tfvars.example
├── scripts/
│   └── setup_switchbot_webhook.sh # SwitchBot Webhook設定スクリプト
├── .env                           # SwitchBot認証情報（gitignoreされています）
├── .env.example                   # 認証情報のテンプレート
├── .terraform-version             # tfenv用のTerraformバージョン指定
├── .gitignore
└── README.md
```

## 機能

- **Webhook受信**: HTTP(S)リクエストを受信
- **ログ出力**: 受信したリクエストの詳細をCloud Loggingに出力
  - リクエストメソッド（GET, POST, PUT等）
  - ヘッダー情報
  - クエリパラメータ
  - リクエストボディ（JSON/Form/Raw）
- **SwitchBot対応**: SwitchBot Webhookに対応
  - Lock/Lock Pro/Lock Ultra（施錠状態、バッテリー残量）
  - Meter/Meter Plus（温度、湿度、バッテリー残量）
  - Motion Sensor（検知状態、明るさ）
  - Contact Sensor（開閉状態、明るさ）
  - Bot（電源状態、バッテリー残量）
  - その他SwitchBotデバイスにも対応
- **環境分離**: dev/prd環境で独立したリソース管理

## 前提条件

### 必要なツール

- **tfenv**: Terraformバージョン管理ツール
- **GCP CLI (gcloud)**: Google Cloud Platform コマンドラインツール
- **GCPプロジェクト**: 以下のプロジェクトが作成済み
  - 開発環境: `room-env-data-pipeline-dev`
  - 本番環境: `room-env-data-pipeline`

### tfenvのインストール

#### macOS (Homebrew)
```bash
brew install tfenv
```

#### Linux
```bash
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Terraformのインストール

プロジェクトルートで以下を実行すると、`.terraform-version`に記載されたバージョンが自動的にインストールされます：

```bash
cd /path/to/room-env-data-pipeline
tfenv install
```

バージョンの確認：
```bash
terraform version
# Terraform v1.6.6 と表示されることを確認
```

### GCP APIの有効化

各プロジェクトで以下のAPIを有効化してください：
- Cloud Functions API
- Cloud Build API
- Cloud Storage API
- Cloud Logging API

開発環境:
```bash
gcloud services enable cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  logging.googleapis.com \
  --project=room-env-data-pipeline-dev
```

本番環境:
```bash
gcloud services enable cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  logging.googleapis.com \
  --project=room-env-data-pipeline
```

### GCPの認証設定

```bash
gcloud auth application-default login
```

## セットアップ

### 1. Terraformのインストール（tfenv使用）

プロジェクトルートに移動して、tfenvでTerraformをインストール：

```bash
cd /path/to/room-env-data-pipeline
tfenv install
```

これにより、`.terraform-version`ファイルに記載されたバージョン（1.6.6）が自動的にインストールされます。

### 2. プロジェクト設定の確認

各環境の`terraform.tfvars`ファイルは既に以下のプロジェクトIDで設定済みです：

- **開発環境** (`env/dev/terraform.tfvars`): `room-env-data-pipeline-dev`
- **本番環境** (`env/prd/terraform.tfvars`): `room-env-data-pipeline`

必要に応じて、リソース設定（メモリ、インスタンス数等）をカスタマイズできます。

### 3. Terraformの初期化とデプロイ

#### 開発環境

```bash
cd env/dev
terraform init
terraform plan
terraform apply
```

#### 本番環境

```bash
cd env/prd
terraform init
terraform plan
terraform apply
```

## デプロイ後の確認

デプロイが完了すると、Webhook URLが出力されます：

```bash
terraform output webhook_url
```

出力例（開発環境）：
```
webhook_url = "https://asia-northeast1-room-env-data-pipeline-dev.cloudfunctions.net/dev-webhook-function"
```

出力例（本番環境）：
```
webhook_url = "https://asia-northeast1-room-env-data-pipeline.cloudfunctions.net/prd-webhook-function"
```

## Webhookのテスト

### curlコマンドでテスト

デプロイ後に `terraform output webhook_url` で取得したURLを使用してテストします。

開発環境の例:
```bash
# Webhook URLを環境変数に設定
WEBHOOK_URL=$(cd env/dev && terraform output -raw webhook_url)

# GETリクエスト
curl "$WEBHOOK_URL?param1=value1"

# POSTリクエスト（JSON）
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, World!", "timestamp": "2025-01-01T00:00:00Z"}' \
  "$WEBHOOK_URL"

# POSTリクエスト（Form）
curl -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "key1=value1&key2=value2" \
  "$WEBHOOK_URL"
```

### レスポンス例

```json
{
  "status": "success",
  "message": "Webhook received successfully",
  "method": "POST",
  "timestamp": null
}
```

## ログの確認

Cloud Loggingでログを確認できます：

開発環境:
```bash
# GCPコンソールから
# https://console.cloud.google.com/logs/query?project=room-env-data-pipeline-dev

# gcloudコマンドから
gcloud functions logs read dev-webhook-function \
  --region=asia-northeast1 \
  --limit=50 \
  --project=room-env-data-pipeline-dev
```

本番環境:
```bash
# GCPコンソールから
# https://console.cloud.google.com/logs/query?project=room-env-data-pipeline

# gcloudコマンドから
gcloud functions logs read prd-webhook-function \
  --region=asia-northeast1 \
  --limit=50 \
  --project=room-env-data-pipeline
```

ログには以下の情報が記録されます：
- リクエストメソッド
- ヘッダー情報
- クエリパラメータ
- リクエストボディ
- レスポンス内容
- SwitchBotデバイスの詳細情報（デバイスタイプ、状態、バッテリー等）

## SwitchBot Webhookの設定

このシステムはSwitchBot Webhookに対応しています。

### SwitchBot APIの設定

1. **SwitchBotアプリでOpen Tokenを取得**
   - SwitchBotアプリ → プロフィール → 設定 → アプリバージョン（10回タップして開発者オプションを有効化）
   - 「トークン」をタップしてOpen TokenとSecret Keyを取得

2. **Webhook URLを設定**

開発環境のWebhook URL:
```
https://asia-northeast1-room-env-data-pipeline-dev.cloudfunctions.net/dev-webhook-function
```

本番環境のWebhook URL:
```
https://asia-northeast1-room-env-data-pipeline.cloudfunctions.net/prd-webhook-function
```

3. **SwitchBot APIでWebhook URLを登録**

`.env`ファイルに認証情報を設定してスクリプトを実行するだけで簡単に設定できます：

```bash
# プロジェクトルートで実行
bash scripts/setup_switchbot_webhook.sh
```

または、手動で設定する場合：

```bash
# 認証情報の設定（.envファイルから読み込み）
source .env
NONCE=$(uuidgen)
T=$(date +%s)000
SIGN=$(echo -n "${SWITCHBOT_TOKEN}${T}${NONCE}" | openssl dgst -sha256 -hmac "${SWITCHBOT_SECRET}" -binary | base64)

# Webhook URLの設定
curl -X POST "https://api.switch-bot.com/v1.1/webhook/setupWebhook" \
  -H "Authorization: ${SWITCHBOT_TOKEN}" \
  -H "sign: ${SIGN}" \
  -H "t: ${T}" \
  -H "nonce: ${NONCE}" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "setupWebhook",
    "url": "https://asia-northeast1-room-env-data-pipeline-dev.cloudfunctions.net/dev-webhook-function",
    "deviceList": "ALL"
  }'

# 設定確認
curl -X POST "https://api.switch-bot.com/v1.1/webhook/queryWebhook" \
  -H "Authorization: ${SWITCHBOT_TOKEN}" \
  -H "sign: ${SIGN}" \
  -H "t: ${T}" \
  -H "nonce: ${NONCE}" \
  -H "Content-Type: application/json" \
  -d '{"action":"queryUrl"}' | jq '.'
```

参考: [SwitchBot API Documentation](https://github.com/OpenWonderLabs/SwitchBotAPI?tab=readme-ov-file#get-webhook-configuration)

### 対応デバイス

現在対応しているSwitchBotデバイス：

| デバイス | 取得データ |
|---------|-----------|
| **Lock/Lock Pro/Lock Ultra** | 施錠状態（LOCKED/UNLOCKED/JAMMED）、バッテリー残量 |
| **Meter/Meter Plus** | 温度、湿度、バッテリー残量 |
| **Motion Sensor** | 検知状態（DETECTED/NOT_DETECTED）、明るさ |
| **Contact Sensor** | 開閉状態（open/close/timeOutNotClose）、明るさ |
| **Bot** | 電源状態（ON/OFF）、バッテリー残量 |

その他のSwitchBotデバイスも基本的な情報を受信・ログ出力できます。

### ログの確認例

SwitchBotデバイスのイベントは、以下のようにログに記録されます：

```
[SwitchBot] Event Type: changeReport, Version: 1
[SwitchBot] Device: WoSensorTH (MAC: AA:BB:CC:DD:EE:FF)
[SwitchBot Meter] Temp: 25.3°C, Humidity: 65%, Battery: 85%
```

```
[SwitchBot] Event Type: changeReport, Version: 1
[SwitchBot] Device: Smart Lock Pro (MAC: 11:22:33:44:55:66)
[SwitchBot Lock] State: LOCKED, Battery: 90%
```

## 設定のカスタマイズ

### Cloud Functionsのリソース設定

`env/{dev,prd}/terraform.tfvars`で以下の設定を調整できます：

```hcl
# インスタンス数
max_instance_count = 10  # 最大インスタンス数
min_instance_count = 0   # 最小インスタンス数（0で自動スケールダウン）

# メモリとタイムアウト
memory          = "512Mi"  # 256Mi, 512Mi, 1Gi, 2Gi, 4Gi, 8Gi
timeout_seconds = 60       # 1-540秒

# 環境変数
environment_variables = {
  ENVIRONMENT = "development"
  LOG_LEVEL   = "INFO"
  CUSTOM_VAR  = "value"
}
```

## リソースの削除

環境を削除する場合：

```bash
# 開発環境
cd env/dev
terraform destroy

# 本番環境
cd env/prd
terraform destroy
```

## セキュリティ考慮事項

現在の設定では、Cloud Functionに対して**パブリックアクセス**が許可されています（Webhookとして機能させるため）。

本番環境で使用する場合は、以下のセキュリティ対策を検討してください：

1. **認証の追加**: 
   - APIキーによる認証
   - Cloud IAMによる認証
   - JWTトークンの検証

2. **Cloud Armorの導入**:
   - DDoS対策
   - レート制限
   - IPアドレス制限

3. **Secret Managerの利用**:
   - API鍵などの機密情報を環境変数ではなくSecret Managerで管理

## トラブルシューティング

### Terraformバージョンの問題

もし異なるTerraformバージョンが使われている場合：

```bash
# 現在のバージョンを確認
terraform version

# .terraform-versionで指定されたバージョンをインストール
tfenv install

# バージョンを切り替え
tfenv use 1.6.6

# または、自動で切り替え（.terraform-versionを読む）
cd env/dev  # プロジェクトルート配下のどこでも可
terraform version
```

### デプロイエラー

開発環境:
```bash
# APIが有効になっているか確認
gcloud services list --enabled --project=room-env-data-pipeline-dev

# 必要に応じてAPIを有効化
gcloud services enable cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  --project=room-env-data-pipeline-dev
```

本番環境:
```bash
# APIが有効になっているか確認
gcloud services list --enabled --project=room-env-data-pipeline

# 必要に応じてAPIを有効化
gcloud services enable cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  --project=room-env-data-pipeline
```

### 権限エラー

Terraformを実行するユーザー/サービスアカウントに以下の権限が必要です：
- Cloud Functions Developer
- Storage Admin
- Service Account User
- IAM Admin（サービスアカウント作成のため）

## ライセンス

MIT License

## サポート

問題や質問がある場合は、GitHubのIssueで報告してください。

