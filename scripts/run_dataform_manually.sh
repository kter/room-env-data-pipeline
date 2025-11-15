#!/bin/bash

# Dataform SQLを手動で実行するスクリプト
# Usage: ./scripts/run_dataform_manually.sh [environment]
#
# Example:
#   ./scripts/run_dataform_manually.sh dev
#   ./scripts/run_dataform_manually.sh prd

set -e

# 環境を引数から取得（デフォルトはdev）
ENVIRONMENT=${1:-dev}

# プロジェクトIDを設定
if [ "$ENVIRONMENT" = "prd" ]; then
  PROJECT_ID="room-env-data-pipeline-prd"
  DATASET_ID="prd_sensor_data"
else
  PROJECT_ID="room-env-data-pipeline-dev"
  DATASET_ID="dev_sensor_data"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Dataform SQL手動実行"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "環境: $ENVIRONMENT"
echo "プロジェクト: $PROJECT_ID"
echo "データセット: $DATASET_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# プロジェクトを設定
gcloud config set project "$PROJECT_ID"

# 1. 時間別統計を作成
echo "📊 1/3: sensor_hourly_stats を作成中..."
bq query \
  --use_legacy_sql=false \
  --project_id="$PROJECT_ID" \
  --destination_table="$PROJECT_ID:$DATASET_ID.sensor_hourly_stats" \
  --replace \
  "SELECT
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
    \`$PROJECT_ID.$DATASET_ID.sensor_raw_data\`
  WHERE
    temperature IS NOT NULL
    OR humidity IS NOT NULL
  GROUP BY
    hour_timestamp,
    device_mac,
    device_type" > /dev/null

echo "✅ sensor_hourly_stats 作成完了"
echo ""

# 2. 日別統計を作成
echo "📊 2/3: sensor_daily_stats を作成中..."
bq query \
  --use_legacy_sql=false \
  --project_id="$PROJECT_ID" \
  --destination_table="$PROJECT_ID:$DATASET_ID.sensor_daily_stats" \
  --replace \
  "SELECT
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
    SUM(event_count) AS event_count,
    CURRENT_TIMESTAMP() AS last_updated
  FROM
    \`$PROJECT_ID.$DATASET_ID.sensor_hourly_stats\`
  GROUP BY
    date,
    device_mac,
    device_type" > /dev/null

echo "✅ sensor_daily_stats 作成完了"
echo ""

# 3. 最新状態を作成
echo "📊 3/3: sensor_latest を作成中..."
bq query \
  --use_legacy_sql=false \
  --project_id="$PROJECT_ID" \
  --destination_table="$PROJECT_ID:$DATASET_ID.sensor_latest" \
  --replace \
  "WITH latest_records AS (
    SELECT
      *,
      ROW_NUMBER() OVER (
        PARTITION BY device_mac, device_type
        ORDER BY timestamp DESC
      ) AS rn
    FROM
      \`$PROJECT_ID.$DATASET_ID.sensor_raw_data\`
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
    temperature - LAG(temperature) OVER (
      PARTITION BY device_mac
      ORDER BY timestamp
    ) AS temperature_change,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), timestamp, MINUTE) AS minutes_since_update
  FROM
    latest_records
  WHERE
    rn = 1" > /dev/null

echo "✅ sensor_latest 作成完了"
echo ""

# 結果を表示
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ すべてのテーブル作成完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 レコード数確認:"
bq query \
  --use_legacy_sql=false \
  --project_id="$PROJECT_ID" \
  "SELECT 
    'sensor_raw_data' as table_name,
    COUNT(*) as record_count
  FROM \`$PROJECT_ID.$DATASET_ID.sensor_raw_data\`
  UNION ALL
  SELECT 
    'sensor_hourly_stats' as table_name,
    COUNT(*) as record_count
  FROM \`$PROJECT_ID.$DATASET_ID.sensor_hourly_stats\`
  UNION ALL
  SELECT 
    'sensor_daily_stats' as table_name,
    COUNT(*) as record_count
  FROM \`$PROJECT_ID.$DATASET_ID.sensor_daily_stats\`
  UNION ALL
  SELECT 
    'sensor_latest' as table_name,
    COUNT(*) as record_count
  FROM \`$PROJECT_ID.$DATASET_ID.sensor_latest\`
  ORDER BY table_name"

echo ""
echo "🎉 完了！"

