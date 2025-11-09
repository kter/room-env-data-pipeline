# Dataform セットアップガイド

## 🎯 目的

BigQueryの生データ（`sensor_raw_data`）から、Looker用の集計テーブルを自動生成します。

## 📋 前提条件

- ✅ BigQueryにデータが保存されている
- ✅ Dataform APIが有効化されている
- ✅ dataform/ディレクトリに定義ファイルが準備済み

## 🚀 セットアップ手順

### Step 1: Dataformコンソールを開く

以下のURLを開いてください：

```
https://console.cloud.google.com/bigquery/dataform?project=room-env-data-pipeline-dev
```

### Step 2: リポジトリの作成

1. **「リポジトリを作成」** をクリック
2. 以下の情報を入力：
   - **リポジトリ ID**: `sensor-data-transformation`
   - **リージョン**: `asia-northeast1`
   - **表示名**: `Sensor Data Transformation`（任意）
3. **「作成」** をクリック

### Step 3: ワークスペースの作成

1. 作成したリポジトリをクリック
2. **「ワークスペースを作成」** をクリック
3. ワークスペース名: `main`（デフォルト）
4. **「作成」** をクリック

### Step 4: ファイルのアップロード

#### 4-1. dataform.json

1. ワークスペースで **「ファイルを作成」** → **「dataform.json」** を選択
2. 以下の内容をコピー＆ペースト：

```json
{
  "defaultSchema": "dev_sensor_data",
  "assertionSchema": "dataform_assertions",
  "defaultDatabase": "room-env-data-pipeline-dev",
  "defaultLocation": "asia-northeast1"
}
```

3. **「保存」** をクリック

#### 4-2. package.json

1. **「ファイルを作成」** をクリック
2. ファイル名: `package.json`
3. 以下の内容をコピー＆ペースト：

```json
{
  "name": "room-env-data-pipeline-dataform",
  "version": "1.0.0",
  "description": "Dataform transformations for SwitchBot sensor data",
  "dependencies": {
    "@dataform/core": "2.9.0"
  }
}
```

4. **「保存」** をクリック

#### 4-3. definitions/ ディレクトリの作成

1. **「フォルダを作成」** をクリック
2. フォルダ名: `definitions`
3. **「作成」** をクリック

#### 4-4. sensor_hourly_stats.sqlx

1. `definitions/` フォルダ内で **「ファイルを作成」** をクリック
2. ファイル名: `sensor_hourly_stats.sqlx`
3. 以下の内容をコピー＆ペースト：

```sql
config {
  type: "incremental",
  schema: "dev_sensor_data",
  description: "時間別のセンサーデータ集計テーブル",
  bigquery: {
    partitionBy: "TIMESTAMP_TRUNC(hour_timestamp, DAY)",
    clusterBy: ["device_mac", "device_type"]
  },
  tags: ["hourly", "aggregation"]
}

-- 生データから1時間ごとの統計を計算
SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS hour_timestamp,
  device_mac,
  device_type,
  AVG(temperature) AS avg_temperature,
  MIN(temperature) AS min_temperature,
  MAX(temperature) AS max_temperature,
  AVG(humidity) AS avg_humidity,
  MIN(humidity) AS min_humidity,
  MAX(humidity) AS max_humidity,
  AVG(battery) AS avg_battery,
  COUNT(*) AS event_count,
  CURRENT_TIMESTAMP() AS last_updated
FROM
  ${ref("sensor_raw_data")}
WHERE
  temperature IS NOT NULL
  OR humidity IS NOT NULL

${ when(incremental(), `AND timestamp > (SELECT MAX(hour_timestamp) FROM ${self()})`) }

GROUP BY
  hour_timestamp,
  device_mac,
  device_type
```

4. **「保存」** をクリック

#### 4-5. sensor_daily_stats.sqlx

1. `definitions/` フォルダ内で **「ファイルを作成」** をクリック
2. ファイル名: `sensor_daily_stats.sqlx`
3. 以下の内容をコピー＆ペースト：

```sql
config {
  type: "table",
  schema: "dev_sensor_data",
  description: "日別のセンサーデータ集計テーブル（Looker用）",
  bigquery: {
    partitionBy: "date",
    clusterBy: ["device_mac", "device_type"]
  },
  tags: ["daily", "aggregation", "looker"]
}

-- 時間別統計から日別統計を計算
SELECT
  DATE(hour_timestamp) AS date,
  device_mac,
  device_type,
  AVG(avg_temperature) AS avg_temperature,
  MIN(min_temperature) AS min_temperature,
  MAX(max_temperature) AS max_temperature,
  AVG(avg_humidity) AS avg_humidity,
  MIN(min_humidity) AS min_humidity,
  MAX(max_humidity) AS max_humidity,
  AVG(avg_battery) AS avg_battery,
  SUM(event_count) AS total_events,
  CURRENT_TIMESTAMP() AS last_updated
FROM
  ${ref("sensor_hourly_stats")}
GROUP BY
  date,
  device_mac,
  device_type
```

4. **「保存」** をクリック

#### 4-6. sensor_latest.sqlx

1. `definitions/` フォルダ内で **「ファイルを作成」** をクリック
2. ファイル名: `sensor_latest.sqlx`
3. 以下の内容をコピー＆ペースト：

```sql
config {
  type: "table",
  schema: "dev_sensor_data",
  description: "各デバイスの最新状態（Lookerダッシュボード用）",
  bigquery: {
    clusterBy: ["device_mac", "device_type"]
  },
  tags: ["latest", "dashboard", "looker"]
}

-- 各デバイスの最新データを取得
WITH latest_records AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY device_mac, device_type
      ORDER BY timestamp DESC
    ) AS rn
  FROM
    ${ref("sensor_raw_data")}
)

SELECT
  device_mac,
  device_type,
  timestamp AS last_updated,
  temperature AS current_temperature,
  humidity AS current_humidity,
  battery AS current_battery,
  lock_state,
  detection_state,
  open_state,
  power_state,
  brightness,
  -- 温度の変化トレンド（過去1時間との比較）
  temperature - LAG(temperature) OVER (
    PARTITION BY device_mac
    ORDER BY timestamp
  ) AS temperature_change,
  -- データ鮮度（最終更新からの経過時間）
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), timestamp, MINUTE) AS minutes_since_update
FROM
  latest_records
WHERE
  rn = 1
```

4. **「保存」** をクリック

### Step 5: ワークフローの実行テスト

1. ワークスペース画面で **「実行を開始」** をクリック
2. **「すべてのアクションを含める」** を選択
3. **「実行を開始」** をクリック

実行が完了すると、以下のテーブルが作成されます：
- `dev_sensor_data.sensor_hourly_stats`
- `dev_sensor_data.sensor_daily_stats`
- `dev_sensor_data.sensor_latest`

### Step 6: スケジュール設定

#### オプション1: Dataformのスケジュール機能（推奨）

1. リポジトリ画面で **「リリース構成」** タブを選択
2. **「構成を作成」** をクリック
3. 以下を設定：
   - **名前**: `hourly-aggregation`
   - **Cron スケジュール**: `0 * * * *`（毎時0分に実行）
   - **タイムゾーン**: `Asia/Tokyo`
   - **含めるタグ**: すべて選択
4. **「作成」** をクリック

#### オプション2: Cloud Scheduler

```bash
# Cloud Scheduler Jobの作成
gcloud scheduler jobs create http sensor-hourly-aggregation \
  --location=asia-northeast1 \
  --schedule="0 * * * *" \
  --time-zone="Asia/Tokyo" \
  --uri="https://dataform.googleapis.com/v1beta1/projects/room-env-data-pipeline-dev/locations/asia-northeast1/repositories/sensor-data-transformation/workflowInvocations" \
  --http-method=POST \
  --oauth-service-account-email=YOUR_SERVICE_ACCOUNT@room-env-data-pipeline-dev.iam.gserviceaccount.com \
  --project=room-env-data-pipeline-dev
```

## ✅ 動作確認

BigQueryで集計テーブルを確認：

```sql
-- 時間別集計データの確認
SELECT * FROM `dev_sensor_data.sensor_hourly_stats` 
ORDER BY hour_timestamp DESC 
LIMIT 10;

-- 日別集計データの確認
SELECT * FROM `dev_sensor_data.sensor_daily_stats` 
ORDER BY date DESC 
LIMIT 10;

-- 最新状態の確認
SELECT * FROM `dev_sensor_data.sensor_latest` 
ORDER BY last_updated DESC;
```

## 📊 次のステップ

1. ✅ Dataform設定完了
2. → Lookerでデータソース接続
3. → ダッシュボード作成
4. → 本番環境（prd）へのデプロイ

## 🔧 トラブルシューティング

### エラー: "Table not found: sensor_raw_data"

**原因**: 生データテーブルが存在しない、またはスキーマ名が違う

**解決策**:
```sql
-- テーブルの存在確認
SELECT table_name 
FROM `dev_sensor_data.INFORMATION_SCHEMA.TABLES` 
WHERE table_name = 'sensor_raw_data';
```

### エラー: "Permission denied"

**原因**: Dataformサービスアカウントに権限が不足

**解決策**:
```bash
# BigQuery権限の付与
gcloud projects add-iam-policy-binding room-env-data-pipeline-dev \
  --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-dataform.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"
```

## 📚 参考資料

- [Dataform ドキュメント](https://cloud.google.com/dataform/docs)
- [Dataform SQLX 構文](https://cloud.google.com/dataform/docs/configure-execution)
- [BigQuery のデータ変換](https://cloud.google.com/bigquery/docs/data-transformations)

