# Room Environment Data Pipeline

GCP Cloud Functionsベースのデータパイプラインシステムです。SwitchBot WebhookからセンサーデータをリアルタイムWEB取得し、BigQueryに保存、Dataformで集計、Lookerで可視化する構成です。Terraformでインフラを管理し、dev/prdの2環境に対応しています。

## アーキテクチャ

```
SwitchBot Webhook
    ↓
Cloud Functions (Webhook受信・データ変換)
    ↓
Pub/Sub (非同期メッセージング)
    ↓
BigQuery Subscription (自動書き込み)
    ↓
BigQuery (生データ保存)
    ↓
Dataform (スケジュール実行で集計)
    ↓
BigQuery (集計テーブル)
    ↓
Looker (ダッシュボード可視化)
```

### アーキテクチャの特徴

- **Cloud Functions**: Webhookエンドポイント。データ受信、パース、Pub/Subへの送信
- **Pub/Sub**: 非同期メッセージキュー。リトライポリシーとDead Letter Queue対応
- **BigQuery Subscription**: Pub/SubからBigQueryへの自動書き込み（サーバーレス）
- **BigQuery**: データウェアハウス。パーティショニングとクラスタリングで高速クエリ
- **Dataform**: SQLベースのデータ変換パイプライン。スケジュール実行で定期集計
- **Looker**: BIツール。リアルタイムダッシュボードとレポート

**メリット**:
- ✅ サーバーレスで運用コストが低い（常時稼働するサーバー不要）
- ✅ オートスケーリングで大量データにも対応
- ✅ Pub/SubとBigQuery Subscriptionでコード不要のETL
- ✅ Dataflowを使わないため、ストリーミングジョブの管理不要

## システム構成

```
room-env-data-pipeline/
├── modules/
│   ├── webhook-function/          # Cloud Functionsモジュール
│   │   ├── main.tf                # Cloud Functionsのリソース定義
│   │   ├── variables.tf           # モジュールの変数定義
│   │   ├── outputs.tf             # モジュールの出力
│   │   └── function-source/       # Cloud Functionのソースコード
│   │       ├── main.py            # Webhookハンドラー（Python）
│   │       └── requirements.txt   # Python依存パッケージ
│   └── data-pipeline/             # データパイプラインモジュール
│       ├── main.tf                # Pub/Sub, BigQuery, IAMのリソース定義
│       ├── variables.tf
│       └── outputs.tf
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
├── dataform/                      # Dataform定義
│   ├── dataform.json              # Dataform設定
│   ├── package.json               # npm依存関係
│   └── definitions/               # SQLXファイル
│       ├── sensor_hourly_stats.sqlx    # 時間別集計
│       ├── sensor_daily_stats.sqlx     # 日別集計
│       └── sensor_latest.sqlx          # 最新状態（Looker用）
├── scripts/
│   └── setup_switchbot_webhook.sh # SwitchBot Webhook設定スクリプト
├── .env                           # SwitchBot認証情報（gitignoreされています）
├── .env.example                   # 認証情報のテンプレート
├── .terraform-version             # tfenv用のTerraformバージョン指定
├── .gitignore
└── README.md
```

## 機能

### 1. Webhook受信（Cloud Functions）
- HTTP(S)リクエストを受信
- リクエストの詳細をCloud Loggingに出力
  - リクエストメソッド（GET, POST, PUT等）
  - ヘッダー情報
  - クエリパラメータ
  - リクエストボディ（JSON/Form/Raw）

### 2. SwitchBot対応
- SwitchBot Webhook形式を自動検出
- デバイスタイプ別のデータパース
  - **Lock/Lock Pro/Lock Ultra**: 施錠状態、バッテリー残量
  - **Meter/Meter Plus**: 温度、湿度、バッテリー残量
  - **Motion Sensor**: 検知状態、明るさ
  - **Contact Sensor**: 開閉状態、明るさ
  - **Bot**: 電源状態、バッテリー残量

### 3. データパイプライン
- **Pub/Sub**: Cloud Functionsから非同期でメッセージ送信
- **BigQuery Subscription**: Pub/SubからBigQueryへ自動書き込み
  - リトライポリシー: 最小10秒〜最大600秒のバックオフ
  - Dead Letter Queue: 5回失敗後にDLQへ
- **BigQuery**: パーティショニング（日次）とクラスタリング（device_mac, device_type）
  - `sensor_raw_data`: 生データテーブル
  - `sensor_hourly_stats`: 時間別集計テーブル（Dataformで生成）
  - `sensor_daily_stats`: 日別集計テーブル（Dataformで生成）
  - `sensor_latest`: 最新状態テーブル（Lookerダッシュボード用）

### 4. Dataform（データ変換）
- SQLXファイルでデータ変換ロジックを定義
- スケジュール実行（Cloud Schedulerと連携）
- インクリメンタル処理で効率的な集計

## 前提条件

### 必要なツール
- Terraform >= 1.0
- tfenv（Terraformバージョン管理）
- gcloud CLI
- GCPプロジェクト
  - **開発環境**: `room-env-data-pipeline-dev`
  - **本番環境**: `room-env-data-pipeline`

### 必要なGCP API
以下のAPIを有効化してください。

#### 開発環境
```bash
gcloud services enable cloudfunctions.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  pubsub.googleapis.com \
  bigquery.googleapis.com \
  dataform.googleapis.com \
  --project=room-env-data-pipeline-dev
```

#### 本番環境
```bash
gcloud services enable cloudfunctions.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  pubsub.googleapis.com \
  bigquery.googleapis.com \
  dataform.googleapis.com \
  --project=room-env-data-pipeline
```

### 必要な権限
- `roles/owner` または以下の権限:
  - `roles/cloudfunctions.admin`
  - `roles/storage.admin`
  - `roles/iam.serviceAccountAdmin`
  - `roles/pubsub.admin`
  - `roles/bigquery.admin`
  - `roles/dataform.admin`

## Gitフロー

このプロジェクトは、環境ごとに異なるGitブランチを使用する戦略を採用しています。

### ブランチ戦略

```
feature/* (機能開発)
    ↓ Pull Request & Merge
develop (開発環境用)
    ↓ Pull Request & Merge
main (本番環境用)
```

### 環境とブランチの対応

| 環境 | ブランチ | Dataform同期ブランチ | プロジェクトID |
|------|---------|---------------------|---------------|
| **開発環境** | `develop` | `develop` | `room-env-data-pipeline-dev` |
| **本番環境** | `main` | `main` | `room-env-data-pipeline` |

### ワークフロー

1. **機能開発**: `feature/*` ブランチで開発
   ```bash
   git checkout -b feature/new-feature
   # コード変更
   git commit -m "feat: 新機能を追加"
   git push origin feature/new-feature
   ```

2. **開発環境へのデプロイ**: `develop` ブランチにマージ
   ```bash
   # GitHubでPull Requestを作成
   # レビュー後、developにマージ
   # → Dataformが自動的にdevelopブランチと同期
   ```

3. **本番環境へのデプロイ**: `main` ブランチにマージ
   ```bash
   # GitHubでdevelop → mainのPull Requestを作成
   # 本番リリース準備完了後、mainにマージ
   # → Dataformが自動的にmainブランチと同期
   ```

### Dataform同期の仕組み

- **dev環境**: Dataformは `develop` ブランチの `dataform/` ディレクトリを自動同期
- **prd環境**: Dataformは `main` ブランチの `dataform/` ディレクトリを自動同期

これにより、Dataformの定義ファイル（`.sqlx`）をGitで管理し、環境ごとに適切なバージョンを自動デプロイできます。

## セットアップ

### 1. tfenvのインストールとTerraformセットアップ

```bash
# tfenvのインストール（Homebrewの場合）
brew install tfenv

# Terraformバージョンのインストール（.terraform-versionに基づく）
tfenv install
tfenv use
```

### 2. Terraformの初期化とデプロイ（開発環境）

プロジェクトIDとBigQueryオーナーのEmailはすでに`terraform.tfvars`に設定されています。

```bash
cd env/dev

# 初期化
terraform init

# プランの確認
terraform plan

# デプロイ
terraform apply
```

### 3. Webhook URLの確認

```bash
cd env/dev
terraform output webhook_url
```

出力例:
```
https://asia-northeast1-room-env-data-pipeline-dev.cloudfunctions.net/dev-webhook-function
```

### 4. SwitchBot Webhook設定

`.env`ファイルを作成して、SwitchBot APIの認証情報を設定します：

```bash
# .envファイルを作成（.env.exampleをコピー）
cp .env.example .env

# エディタで.envファイルを編集
# SWITCHBOT_TOKEN="your_token_here"
# SWITCHBOT_SECRET="your_secret_here"
```

設定スクリプトを実行：

```bash
chmod +x scripts/setup_switchbot_webhook.sh
./scripts/setup_switchbot_webhook.sh
```

## BigQueryテーブル

### sensor_raw_data（生データテーブル）

| カラム | 型 | 説明 |
|--------|-----|------|
| timestamp | TIMESTAMP | イベントタイムスタンプ |
| device_mac | STRING | デバイスMACアドレス |
| device_type | STRING | デバイスタイプ |
| event_type | STRING | イベントタイプ |
| temperature | FLOAT | 温度（℃） |
| humidity | INTEGER | 湿度（%） |
| battery | INTEGER | バッテリー残量（%） |
| lock_state | STRING | 施錠状態 |
| detection_state | STRING | 検知状態 |
| open_state | STRING | 開閉状態 |
| power_state | STRING | 電源状態 |
| brightness | STRING | 明るさ |
| raw_data | JSON | 完全な生データ |
| inserted_at | TIMESTAMP | BigQuery挿入時刻 |

### sensor_hourly_stats（時間別集計テーブル）

Dataformによって生成されます。

| カラム | 型 | 説明 |
|--------|-----|------|
| hour_timestamp | TIMESTAMP | 時間（時の開始） |
| device_mac | STRING | デバイスMACアドレス |
| device_type | STRING | デバイスタイプ |
| avg_temperature | FLOAT | 平均温度 |
| min_temperature | FLOAT | 最低温度 |
| max_temperature | FLOAT | 最高温度 |
| avg_humidity | FLOAT | 平均湿度 |
| min_humidity | INTEGER | 最低湿度 |
| max_humidity | INTEGER | 最高湿度 |
| avg_battery | FLOAT | 平均バッテリー残量 |
| event_count | INTEGER | イベント数 |
| last_updated | TIMESTAMP | 最終更新時刻 |

### sensor_latest（最新状態テーブル）

Lookerダッシュボード用。各デバイスの最新状態を表示。

| カラム | 型 | 説明 |
|--------|-----|------|
| device_mac | STRING | デバイスMACアドレス |
| device_type | STRING | デバイスタイプ |
| last_updated | TIMESTAMP | 最終更新時刻 |
| current_temperature | FLOAT | 現在の温度 |
| current_humidity | INTEGER | 現在の湿度 |
| current_battery | INTEGER | 現在のバッテリー残量 |
| temperature_change | FLOAT | 温度の変化（前回比） |
| minutes_since_update | INTEGER | 最終更新からの経過時間（分） |

## Dataform設定

### Dataformリポジトリの作成（GCPコンソール）

1. GCPコンソールで **Dataform** を開く
2. **リポジトリを作成** をクリック
3. リポジトリ名: `sensor-data-transformation`
4. リージョン: `asia-northeast1`
5. ワークスペースを作成
6. `dataform/`ディレクトリの内容をアップロード

### スケジュール実行の設定

Cloud Schedulerでワークフローを定期実行できます。

```bash
# 1時間ごとに実行する例
gcloud scheduler jobs create app-engine sensor-hourly-aggregation \
  --schedule="0 * * * *" \
  --time-zone="Asia/Tokyo" \
  --location=asia-northeast1 \
  --uri="https://dataform.googleapis.com/v1beta1/projects/room-env-data-pipeline-dev/locations/asia-northeast1/repositories/sensor-data-transformation/workspaces/main/workflows" \
  --http-method=POST \
  --project=room-env-data-pipeline-dev
```

または、Dataformのスケジュール機能を使用：
1. Dataformコンソールで **Release Configurations** を開く
2. 新しいスケジュールを作成
3. Cron式を設定（例: `0 * * * *` で毎時）

## Looker設定

### Lookerでデータソース接続

1. Lookerで **Admin > Connections** を開く
2. **Add Connection** をクリック
3. 以下を設定：
   - Name: `room-env-bigquery`
   - Database: `BigQuery`
   - Project ID: `room-env-data-pipeline-dev` （または `room-env-data-pipeline`）
   - Dataset: `dev_sensor_data` （または `prd_sensor_data`）
4. サービスアカウントの認証情報を設定

### Lookerダッシュボード作成

推奨するビジュアライゼーション：

**現在の状態（sensor_latest）**:
- 温度ゲージ
- 湿度ゲージ
- バッテリー残量インジケータ
- 最終更新時刻

**履歴データ（sensor_hourly_stats / sensor_daily_stats）**:
- 温度・湿度の折れ線グラフ（時系列）
- 温度・湿度の分布ヒストグラム
- デバイス別比較グラフ

## デプロイ後の確認

### Webhookのテスト

#### 開発環境
```bash
# 環境変数設定
export WEBHOOK_URL="https://asia-northeast1-room-env-data-pipeline-dev.cloudfunctions.net/dev-webhook-function"

# テストデータ送信
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "changeReport",
    "eventVersion": "1",
    "context": {
      "deviceType": "WoSensorTH",
      "deviceMac": "TEST123456",
      "timeOfSample": 1234567890000,
      "temperature": 25.5,
      "humidity": 65,
      "battery": 85
    }
  }'
```

#### 本番環境
```bash
export WEBHOOK_URL="https://asia-northeast1-room-env-data-pipeline.cloudfunctions.net/prd-webhook-function"

# （同様のcurlコマンド）
```

### ログの確認

#### Cloud Functionsのログ
```bash
# 開発環境
gcloud functions logs read dev-webhook-function \
  --project=room-env-data-pipeline-dev \
  --region=asia-northeast1 \
  --limit=50

# 本番環境
gcloud functions logs read prd-webhook-function \
  --project=room-env-data-pipeline \
  --region=asia-northeast1 \
  --limit=50
```

SwitchBotデバイスの詳細な情報（温度、湿度、バッテリー残量等）もログに出力されます。

#### BigQueryでデータ確認

```bash
# 開発環境
bq query --project_id=room-env-data-pipeline-dev --use_legacy_sql=false \
'SELECT timestamp, device_mac, device_type, temperature, humidity, battery 
FROM `room-env-data-pipeline-dev.dev_sensor_data.sensor_raw_data` 
ORDER BY timestamp DESC 
LIMIT 10'

# 時間別集計データの確認
bq query --project_id=room-env-data-pipeline-dev --use_legacy_sql=false \
'SELECT hour_timestamp, device_type, avg_temperature, avg_humidity, event_count 
FROM `room-env-data-pipeline-dev.dev_sensor_data.sensor_hourly_stats` 
ORDER BY hour_timestamp DESC 
LIMIT 10'
```

#### Pub/Sub Subscriptionの確認

```bash
# Subscription状態の確認
gcloud pubsub subscriptions describe dev-switchbot-to-bigquery \
  --project=room-env-data-pipeline-dev

# Dead Letter Queueの確認
gcloud pubsub topics list --project=room-env-data-pipeline-dev | grep dlq
```

## SwitchBot Webhookの設定

### 1. トークンとクライアントシークレットの取得

SwitchBotアプリで以下の手順で取得：

1. SwitchBotアプリを開く
2. プロフィール → 設定 → アプリバージョン（10回タップ）
3. 開発者オプション → トークンを取得

### 2. Webhook URLの確認

- **開発環境**: `https://asia-northeast1-room-env-data-pipeline-dev.cloudfunctions.net/dev-webhook-function`
- **本番環境**: `https://asia-northeast1-room-env-data-pipeline.cloudfunctions.net/prd-webhook-function`

### 3. 認証情報の設定

`.env`ファイルを作成：

```bash
SWITCHBOT_TOKEN="your_token_here"
SWITCHBOT_SECRET="your_secret_here"
```

### 4. Webhook登録スクリプトの実行

```bash
# 開発環境用（デフォルト）
./scripts/setup_switchbot_webhook.sh
```

スクリプトは以下を実行します：
1. 現在のWebhook設定を取得
2. 新しいWebhook URLを設定
3. 設定後の状態を確認

### 5. 手動でWebhookを設定する場合

#### 署名の生成（必須）

SwitchBot APIは署名認証が必要です：

```bash
TOKEN="your_token"
SECRET="your_secret"
NONCE=$(uuidgen)
T=$(date +%s)000
SIGN=$(echo -n "${TOKEN}${T}${NONCE}" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

curl -X POST "https://api.switch-bot.com/v1.1/webhook/setupWebhook" \
  -H "Authorization: ${TOKEN}" \
  -H "sign: ${SIGN}" \
  -H "t: ${T}" \
  -H "nonce: ${NONCE}" \
  -H "Content-Type: application/json" \
  -d "{
    \"action\": \"setupWebhook\",
    \"url\": \"$WEBHOOK_URL\",
    \"deviceList\": \"ALL\"
  }"
```

## トラブルシューティング

### APIが有効化されていないエラー

```bash
# 開発環境
gcloud services list --enabled --project=room-env-data-pipeline-dev

# 必要なAPIを有効化
gcloud services enable cloudfunctions.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  pubsub.googleapis.com \
  bigquery.googleapis.com \
  dataform.googleapis.com \
  --project=room-env-data-pipeline-dev
```

### Webhookが403エラーを返す

Cloud Functions 2nd genはCloud Runを内部で使用しているため、`run.invoker`権限が必要です。
これはTerraformで自動設定されていますが、手動で確認する場合：

```bash
gcloud run services add-iam-policy-binding dev-webhook-function \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --region=asia-northeast1 \
  --project=room-env-data-pipeline-dev
```

### BigQueryにデータが入らない

#### Pub/Sub Subscriptionの状態確認
```bash
gcloud pubsub subscriptions describe dev-switchbot-to-bigquery \
  --project=room-env-data-pipeline-dev
```

#### BigQuery APIのログ確認
```bash
gcloud logging read 'resource.type="pubsub_subscription" AND resource.labels.subscription_id="dev-switchbot-to-bigquery"' \
  --project=room-env-data-pipeline-dev \
  --limit=20
```

#### Dead Letter Queueの確認
```bash
# DLQにメッセージがあるか確認
gcloud pubsub topics list --project=room-env-data-pipeline-dev | grep dlq
```

### Dataformが実行できない

#### 権限の確認
```bash
# Dataform用のサービスアカウントにBigQuery権限を付与
gcloud projects add-iam-policy-binding room-env-data-pipeline-dev \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-dataform.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"
```

## 本番環境へのデプロイ

開発環境で動作確認後、本番環境にデプロイ：

```bash
cd env/prd

# 初期化
terraform init

# プランの確認
terraform plan

# デプロイ
terraform apply
```

## クリーンアップ

### 開発環境の削除
```bash
cd env/dev
terraform destroy
```

### 本番環境の削除
```bash
cd env/prd
terraform destroy
```

## ライセンス

MIT License

## 参考資料

- [SwitchBot API Documentation](https://github.com/OpenWonderLabs/SwitchBotAPI)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Functions (2nd gen) Documentation](https://cloud.google.com/functions/docs)
- [Pub/Sub BigQuery Subscription](https://cloud.google.com/pubsub/docs/bigquery)
- [Dataform Documentation](https://cloud.google.com/dataform/docs)
- [Looker Documentation](https://cloud.google.com/looker/docs)
