# Looker セットアップガイド

## 🎯 目的

BigQueryに保存されたセンサーデータをLookerで可視化し、リアルタイムダッシュボードを作成します。

## 📊 利用可能なテーブル

### 1. sensor_latest（推奨: ダッシュボード用）
```
room-env-data-pipeline-dev.dev_sensor_data.sensor_latest
```

**用途**: 現在の温度・湿度を表示するダッシュボード

**カラム**:
- `device_mac`: デバイスMAC アドレス
- `device_type`: デバイスタイプ
- `last_updated`: 最終更新時刻
- `current_temperature`: 現在の温度 (°C)
- `current_humidity`: 現在の湿度 (%)
- `current_battery`: バッテリー残量 (%)
- `minutes_since_update`: 最終更新からの経過時間（分）

### 2. sensor_hourly_stats（推奨: 折れ線グラフ用）
```
room-env-data-pipeline-dev.dev_sensor_data.sensor_hourly_stats
```

**用途**: 時系列の温度・湿度推移グラフ

**カラム**:
- `hour_timestamp`: 時刻（1時間単位）
- `device_mac`: デバイスMAC アドレス
- `device_type`: デバイスタイプ
- `avg_temperature`: 平均温度 (°C)
- `min_temperature`: 最低温度 (°C)
- `max_temperature`: 最高温度 (°C)
- `avg_humidity`: 平均湿度 (%)
- `min_humidity`: 最低湿度 (%)
- `max_humidity`: 最高湿度 (%)
- `avg_battery`: 平均バッテリー残量 (%)
- `event_count`: イベント数
- `last_updated`: 集計実行時刻

### 3. sensor_daily_stats（オプション: 日別レポート用）
```
room-env-data-pipeline-dev.dev_sensor_data.sensor_daily_stats
```

**用途**: 日別の統計レポート

**カラム**:
- `date`: 日付
- `device_mac`: デバイスMAC アドレス
- `device_type`: デバイスタイプ
- `avg_temperature`: 平均温度 (°C)
- `min_temperature`: 最低温度 (°C)
- `max_temperature`: 最高温度 (°C)
- `avg_humidity`: 平均湿度 (%)
- `min_humidity`: 最低湿度 (%)
- `max_humidity`: 最高湿度 (%)
- `avg_battery`: 平均バッテリー残量 (%)
- `total_events`: 総イベント数
- `last_updated`: 集計実行時刻

## 🚀 Looker セットアップ手順

### Step 1: BigQuery接続の作成

1. Lookerにログイン
2. **Admin → Connections** に移動
3. **Add Connection** をクリック
4. 以下を設定：
   - **Name**: `room-env-data-pipeline-dev`
   - **Dialect**: `Google BigQuery Standard SQL`
   - **Project ID**: `room-env-data-pipeline-dev`
   - **Dataset**: `dev_sensor_data`
   - **Authentication**: `Service Account` または `OAuth`

5. **Test Connection** で接続確認
6. **Save** をクリック

### Step 2: LookML プロジェクトの作成

#### 2-1. プロジェクト作成

1. **Develop → Projects** に移動
2. **New LookML Project** をクリック
3. プロジェクト名: `room_env_sensor_data`
4. **Create Project** をクリック

#### 2-2. ビューファイルの作成

##### sensor_latest.view.lkml

```lkml
view: sensor_latest {
  sql_table_name: `room-env-data-pipeline-dev.dev_sensor_data.sensor_latest` ;;

  dimension: device_mac {
    type: string
    sql: ${TABLE}.device_mac ;;
    label: "デバイスMAC"
  }

  dimension: device_type {
    type: string
    sql: ${TABLE}.device_type ;;
    label: "デバイスタイプ"
  }

  dimension_group: last_updated {
    type: time
    timeframes: [raw, time, date, hour, minute]
    sql: ${TABLE}.last_updated ;;
    label: "最終更新"
  }

  measure: current_temperature {
    type: average
    sql: ${TABLE}.current_temperature ;;
    value_format_name: decimal_2
    label: "現在の温度 (°C)"
    drill_fields: [device_mac, current_temperature]
  }

  measure: current_humidity {
    type: average
    sql: ${TABLE}.current_humidity ;;
    value_format_name: decimal_1
    label: "現在の湿度 (%)"
    drill_fields: [device_mac, current_humidity]
  }

  measure: current_battery {
    type: average
    sql: ${TABLE}.current_battery ;;
    value_format_name: decimal_0
    label: "バッテリー残量 (%)"
    drill_fields: [device_mac, current_battery]
  }

  dimension: minutes_since_update {
    type: number
    sql: ${TABLE}.minutes_since_update ;;
    label: "最終更新からの経過時間（分）"
  }

  dimension: is_recent {
    type: yesno
    sql: ${minutes_since_update} < 60 ;;
    label: "直近1時間以内のデータ"
  }
}
```

##### sensor_hourly_stats.view.lkml

```lkml
view: sensor_hourly_stats {
  sql_table_name: `room-env-data-pipeline-dev.dev_sensor_data.sensor_hourly_stats` ;;

  dimension: device_mac {
    type: string
    sql: ${TABLE}.device_mac ;;
    label: "デバイスMAC"
  }

  dimension: device_type {
    type: string
    sql: ${TABLE}.device_type ;;
    label: "デバイスタイプ"
  }

  dimension_group: hour {
    type: time
    timeframes: [raw, time, date, hour, day_of_week, month, year]
    sql: ${TABLE}.hour_timestamp ;;
    label: "時刻"
  }

  measure: avg_temperature {
    type: average
    sql: ${TABLE}.avg_temperature ;;
    value_format_name: decimal_2
    label: "平均温度 (°C)"
    drill_fields: [device_mac, hour_time, avg_temperature]
  }

  measure: min_temperature {
    type: min
    sql: ${TABLE}.min_temperature ;;
    value_format_name: decimal_2
    label: "最低温度 (°C)"
  }

  measure: max_temperature {
    type: max
    sql: ${TABLE}.max_temperature ;;
    value_format_name: decimal_2
    label: "最高温度 (°C)"
  }

  measure: avg_humidity {
    type: average
    sql: ${TABLE}.avg_humidity ;;
    value_format_name: decimal_1
    label: "平均湿度 (%)"
    drill_fields: [device_mac, hour_time, avg_humidity]
  }

  measure: min_humidity {
    type: min
    sql: ${TABLE}.min_humidity ;;
    value_format_name: decimal_1
    label: "最低湿度 (%)"
  }

  measure: max_humidity {
    type: max
    sql: ${TABLE}.max_humidity ;;
    value_format_name: decimal_1
    label: "最高湿度 (%)"
  }

  measure: avg_battery {
    type: average
    sql: ${TABLE}.avg_battery ;;
    value_format_name: decimal_0
    label: "平均バッテリー (%)"
  }

  measure: event_count {
    type: sum
    sql: ${TABLE}.event_count ;;
    label: "イベント数"
  }
}
```

##### sensor_daily_stats.view.lkml

```lkml
view: sensor_daily_stats {
  sql_table_name: `room-env-data-pipeline-dev.dev_sensor_data.sensor_daily_stats` ;;

  dimension: device_mac {
    type: string
    sql: ${TABLE}.device_mac ;;
    label: "デバイスMAC"
  }

  dimension: device_type {
    type: string
    sql: ${TABLE}.device_type ;;
    label: "デバイスタイプ"
  }

  dimension_group: date {
    type: time
    timeframes: [raw, date, week, month, year]
    sql: ${TABLE}.date ;;
    label: "日付"
  }

  measure: avg_temperature {
    type: average
    sql: ${TABLE}.avg_temperature ;;
    value_format_name: decimal_2
    label: "平均温度 (°C)"
  }

  measure: min_temperature {
    type: min
    sql: ${TABLE}.min_temperature ;;
    value_format_name: decimal_2
    label: "最低温度 (°C)"
  }

  measure: max_temperature {
    type: max
    sql: ${TABLE}.max_temperature ;;
    value_format_name: decimal_2
    label: "最高温度 (°C)"
  }

  measure: avg_humidity {
    type: average
    sql: ${TABLE}.avg_humidity ;;
    value_format_name: decimal_1
    label: "平均湿度 (%)"
  }

  measure: total_events {
    type: sum
    sql: ${TABLE}.total_events ;;
    label: "総イベント数"
  }
}
```

#### 2-3. モデルファイルの作成

##### room_env_sensor_data.model.lkml

```lkml
connection: "room-env-data-pipeline-dev"

include: "*.view.lkml"

explore: sensor_latest {
  label: "センサー最新状態"
  description: "各デバイスの現在の温度・湿度・バッテリー状態"
}

explore: sensor_hourly_stats {
  label: "センサー時系列データ"
  description: "時間別の温度・湿度推移"
}

explore: sensor_daily_stats {
  label: "センサー日別統計"
  description: "日別の温度・湿度統計"
}
```

#### 2-4. 変更をコミット

1. **Validate LookML** で構文チェック
2. **Commit Changes** でコミット
3. **Deploy to Production** で本番環境にデプロイ

### Step 3: ダッシュボードの作成

#### 3-1. 新規ダッシュボード作成

1. **Dashboards → New Dashboard** をクリック
2. ダッシュボード名: `Room Environment Monitor`
3. **Create Dashboard** をクリック

#### 3-2. タイルの追加

##### タイル 1: 現在の温度（Single Value）

- **Explore**: `sensor_latest`
- **Visualization**: Single Value
- **Measure**: `Current Temperature`
- **Filters**: `Is Recent = Yes`
- **Title**: `現在の温度`
- **Style**: Large font, conditional formatting (温度に応じた色分け)

##### タイル 2: 現在の湿度（Single Value）

- **Explore**: `sensor_latest`
- **Visualization**: Single Value
- **Measure**: `Current Humidity`
- **Filters**: `Is Recent = Yes`
- **Title**: `現在の湿度`
- **Style**: Large font

##### タイル 3: 温度推移（Line Chart）

- **Explore**: `sensor_hourly_stats`
- **Visualization**: Line Chart
- **Dimensions**: `Hour Time`
- **Measures**: `Avg Temperature`
- **Pivots**: `Device MAC`（デバイス別に色分け）
- **Filters**: `Hour Date is in the last 24 hours`
- **Title**: `温度推移（24時間）`
- **X-Axis**: Time
- **Y-Axis**: Temperature (°C)

##### タイル 4: 湿度推移（Line Chart）

- **Explore**: `sensor_hourly_stats`
- **Visualization**: Line Chart
- **Dimensions**: `Hour Time`
- **Measures**: `Avg Humidity`
- **Pivots**: `Device MAC`
- **Filters**: `Hour Date is in the last 24 hours`
- **Title**: `湿度推移（24時間）`
- **X-Axis**: Time
- **Y-Axis**: Humidity (%)

##### タイル 5: バッテリー残量（Bar Chart）

- **Explore**: `sensor_latest`
- **Visualization**: Bar Chart
- **Dimensions**: `Device MAC`
- **Measures**: `Current Battery`
- **Title**: `デバイス別バッテリー残量`
- **Sort**: By battery level (ascending)

##### タイル 6: デバイス状態テーブル（Table）

- **Explore**: `sensor_latest`
- **Visualization**: Table
- **Dimensions**: `Device MAC`, `Device Type`, `Last Updated Time`
- **Measures**: `Current Temperature`, `Current Humidity`, `Current Battery`
- **Title**: `全デバイス状態`

#### 3-3. ダッシュボードの設定

- **Auto Refresh**: 5分ごと（リアルタイム更新）
- **Filters**: デバイスタイプ、時間範囲
- **Layout**: グリッドレイアウトで見やすく配置

### Step 4: スケジュール配信の設定（オプション）

1. ダッシュボード画面で **Schedule → New Schedule** をクリック
2. 配信設定：
   - **Frequency**: Daily at 9:00 AM
   - **Format**: PDF
   - **Recipients**: メールアドレス
3. **Save Schedule** をクリック

## 📊 推奨ダッシュボードレイアウト

```
┌─────────────────────────────────────────────────────────────┐
│                  Room Environment Monitor                   │
├──────────────────┬──────────────────┬──────────────────────┤
│  現在の温度      │  現在の湿度      │  バッテリー残量      │
│    24.5°C        │     59%          │  [バーチャート]     │
└──────────────────┴──────────────────┴──────────────────────┘
├─────────────────────────────────────────────────────────────┤
│                  温度推移（24時間）                         │
│  [折れ線グラフ: デバイス別に色分け]                        │
└─────────────────────────────────────────────────────────────┘
├─────────────────────────────────────────────────────────────┤
│                  湿度推移（24時間）                         │
│  [折れ線グラフ: デバイス別に色分け]                        │
└─────────────────────────────────────────────────────────────┘
├─────────────────────────────────────────────────────────────┤
│                  全デバイス状態テーブル                     │
│  [テーブル: MAC | タイプ | 温度 | 湿度 | バッテリー]       │
└─────────────────────────────────────────────────────────────┘
```

## ✅ 動作確認

### 1. Exploreで データ確認

```
Explore → sensor_latest
```

デバイスの最新データが表示されることを確認

### 2. ダッシュボードの表示確認

```
Dashboards → Room Environment Monitor
```

すべてのタイルにデータが表示されることを確認

### 3. 自動更新の確認

5分待って、ダッシュボードが自動更新されることを確認

## 🔧 トラブルシューティング

### エラー: "Table not found"

**原因**: BigQuery接続のDataset設定が間違っている

**解決策**:
```
Admin → Connections → room-env-data-pipeline-dev
Dataset を "dev_sensor_data" に設定
```

### エラー: "Permission denied"

**原因**: サービスアカウントにBigQuery読み取り権限がない

**解決策**:
```bash
gcloud projects add-iam-policy-binding room-env-data-pipeline-dev \
  --member="serviceAccount:looker-sa@room-env-data-pipeline-dev.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"
```

### データが表示されない

**原因**: BigQueryテーブルにデータが入っていない

**解決策**:
```sql
-- BigQueryでデータ確認
SELECT COUNT(*) FROM `dev_sensor_data.sensor_latest`;
```

## 📚 参考資料

- [Looker Documentation](https://cloud.google.com/looker/docs)
- [LookML Reference](https://cloud.google.com/looker/docs/lookml-reference)
- [Looker Visualizations](https://cloud.google.com/looker/docs/visualizations)

## 🎯 次のステップ

1. ✅ BigQuery集計テーブル作成完了
2. ✅ Looker セットアップガイド作成完了
3. → Lookerでダッシュボード作成（このガイドに従って実施）
4. → Dataformでスケジュール設定（自動集計）
5. → 本番環境（prd）へのデプロイ

