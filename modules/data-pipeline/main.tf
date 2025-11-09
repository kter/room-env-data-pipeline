terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Pub/Subトピック（SwitchBotイベント用）
resource "google_pubsub_topic" "switchbot_events" {
  name    = "${var.environment}-switchbot-events"
  project = var.project_id

  message_retention_duration = "86400s" # 24時間
  
  labels = {
    environment = var.environment
    purpose     = "switchbot-webhook"
  }
}

# BigQueryデータセット
resource "google_bigquery_dataset" "sensor_data" {
  dataset_id    = "${var.environment}_sensor_data"
  project       = var.project_id
  location      = var.region
  friendly_name = "Sensor Data (${var.environment})"
  description   = "SwitchBot sensor raw data for ${var.environment} environment"

  labels = {
    environment = var.environment
  }

  # データの保持期間（オプション）。0の場合は無期限
  default_table_expiration_ms = var.table_expiration_days > 0 ? var.table_expiration_days * 24 * 60 * 60 * 1000 : null

  access {
    role          = "OWNER"
    user_by_email = var.bigquery_owner_email
  }
}

# BigQueryテーブル（生データ）
resource "google_bigquery_table" "sensor_raw_data" {
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "sensor_raw_data"
  project    = var.project_id

  labels = {
    environment = var.environment
    type        = "raw"
  }

  time_partitioning {
    type  = "DAY"
    field = "timestamp"
  }

  clustering = ["device_mac", "device_type"]

  schema = jsonencode([
    {
      name        = "timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Event timestamp"
    },
    {
      name        = "device_mac"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Device MAC address"
    },
    {
      name        = "device_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Device type (e.g., WoSensorTH, Smart Lock Pro)"
    },
    {
      name        = "event_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Event type (e.g., changeReport)"
    },
    {
      name        = "event_version"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Event version"
    },
    {
      name        = "temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Temperature in Celsius"
    },
    {
      name        = "humidity"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Humidity percentage"
    },
    {
      name        = "battery"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Battery level percentage"
    },
    {
      name        = "lock_state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Lock state (LOCKED, UNLOCKED, JAMMED)"
    },
    {
      name        = "detection_state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Motion detection state"
    },
    {
      name        = "open_state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Contact sensor open state"
    },
    {
      name        = "power_state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Power state (ON, OFF)"
    },
    {
      name        = "brightness"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Brightness level"
    },
    {
      name        = "raw_data"
      type        = "JSON"
      mode        = "REQUIRED"
      description = "Full raw event data"
    },
    {
      name        = "inserted_at"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "When the record was inserted into BigQuery"
    }
  ])
}

# BigQuery Subscription（Pub/Sub → BigQuery）
resource "google_pubsub_subscription" "bigquery_subscription" {
  name    = "${var.environment}-switchbot-to-bigquery"
  topic   = google_pubsub_topic.switchbot_events.name
  project = var.project_id

  bigquery_config {
    table               = "${var.project_id}:${google_bigquery_dataset.sensor_data.dataset_id}.${google_bigquery_table.sensor_raw_data.table_id}"
    write_metadata      = false  # メタデータカラムを追加しない
    use_topic_schema    = false
    use_table_schema    = true
    drop_unknown_fields = false
  }

  # メッセージの保持期間
  message_retention_duration = "86400s" # 24時間

  # 再試行ポリシー
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # Dead Letter Queue（オプション）
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.switchbot_events_dlq.id
    max_delivery_attempts = 5
  }

  depends_on = [
    google_bigquery_table.sensor_raw_data,
    google_bigquery_dataset_iam_member.pubsub_editor,
    google_bigquery_table_iam_member.pubsub_table_editor,
    google_project_iam_member.pubsub_bigquery_metadata
  ]
}

# Dead Letter Queue用のトピック
resource "google_pubsub_topic" "switchbot_events_dlq" {
  name    = "${var.environment}-switchbot-events-dlq"
  project = var.project_id

  message_retention_duration = "604800s" # 7日間

  labels = {
    environment = var.environment
    purpose     = "dead-letter-queue"
  }
}

# BigQuery集計テーブル（Dataform用）
resource "google_bigquery_table" "sensor_hourly_stats" {
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "sensor_hourly_stats"
  project    = var.project_id

  labels = {
    environment = var.environment
    type        = "aggregated"
  }

  time_partitioning {
    type  = "DAY"
    field = "hour_timestamp"
  }

  clustering = ["device_mac", "device_type"]

  schema = jsonencode([
    {
      name        = "hour_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Hour timestamp (start of hour)"
    },
    {
      name        = "device_mac"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Device MAC address"
    },
    {
      name        = "device_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Device type"
    },
    {
      name        = "avg_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Average temperature"
    },
    {
      name        = "min_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Minimum temperature"
    },
    {
      name        = "max_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Maximum temperature"
    },
    {
      name        = "avg_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Average humidity"
    },
    {
      name        = "min_humidity"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Minimum humidity"
    },
    {
      name        = "max_humidity"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Maximum humidity"
    },
    {
      name        = "avg_battery"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Average battery level"
    },
    {
      name        = "event_count"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Number of events in this hour"
    },
    {
      name        = "last_updated"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "When this record was last updated"
    }
  ])
}

# 日別統計テーブル
resource "google_bigquery_table" "sensor_daily_stats" {
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "sensor_daily_stats"
  project    = var.project_id

  labels = {
    environment = var.environment
    type        = "aggregated"
  }

  time_partitioning {
    type  = "DAY"
    field = "date"
  }

  clustering = ["device_mac", "device_type"]

  schema = jsonencode([
    {
      name        = "date"
      type        = "DATE"
      mode        = "REQUIRED"
      description = "Date"
    },
    {
      name        = "device_mac"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Device MAC address"
    },
    {
      name        = "device_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Device type"
    },
    {
      name        = "avg_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Average temperature"
    },
    {
      name        = "min_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Minimum temperature"
    },
    {
      name        = "max_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Maximum temperature"
    },
    {
      name        = "avg_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Average humidity"
    },
    {
      name        = "min_humidity"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Minimum humidity"
    },
    {
      name        = "max_humidity"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Maximum humidity"
    },
    {
      name        = "avg_battery"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Average battery level"
    },
    {
      name        = "total_events"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Total number of events in this day"
    },
    {
      name        = "last_updated"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "When this record was last updated"
    }
  ])
}

# 最新状態テーブル（Looker用）
resource "google_bigquery_table" "sensor_latest" {
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "sensor_latest"
  project    = var.project_id

  labels = {
    environment = var.environment
    type        = "aggregated"
  }

  clustering = ["device_mac", "device_type"]

  schema = jsonencode([
    {
      name        = "device_mac"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Device MAC address"
    },
    {
      name        = "device_type"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Device type"
    },
    {
      name        = "last_updated"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Last update timestamp"
    },
    {
      name        = "current_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Current temperature"
    },
    {
      name        = "current_humidity"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Current humidity"
    },
    {
      name        = "current_battery"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Current battery level"
    },
    {
      name        = "lock_state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Lock state"
    },
    {
      name        = "detection_state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Motion detection state"
    },
    {
      name        = "open_state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Contact sensor open state"
    },
    {
      name        = "power_state"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Power state"
    },
    {
      name        = "brightness"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Brightness level"
    },
    {
      name        = "minutes_since_update"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Minutes since last update"
    }
  ])
}

# Pub/Sub Publisher権限をCloud Functionsのサービスアカウントに付与
resource "google_pubsub_topic_iam_member" "publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.switchbot_events.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.function_service_account_email}"
}

# Pub/Sub service accountを取得するためのdata source
data "google_project" "project" {
  project_id = var.project_id
}

# BigQueryへのアクセス権限をPub/Sub service accountに付与
resource "google_bigquery_dataset_iam_member" "pubsub_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# BigQueryメタデータアクセス権限をPub/Sub service accountに付与
resource "google_project_iam_member" "pubsub_bigquery_metadata" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Pub/Sub service accountにBigQueryテーブルへの直接書き込み権限を付与
resource "google_bigquery_table_iam_member" "pubsub_table_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = google_bigquery_table.sensor_raw_data.table_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# BigQuery Storage Write API用の権限を付与
resource "google_project_iam_member" "pubsub_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ============================================================================
# Dataform
# ============================================================================

# Dataform API有効化
resource "google_project_service" "dataform" {
  project = var.project_id
  service = "dataform.googleapis.com"

  disable_on_destroy = false
}

# Dataformリポジトリ
resource "google_dataform_repository" "sensor_data_transformation" {
  provider = google-beta
  
  name    = "${var.environment}-sensor-data-transformation"
  region  = var.region
  project = var.project_id

  labels = {
    environment = var.environment
    purpose     = "data-transformation"
  }

  depends_on = [google_project_service.dataform]
}

# Dataformリリース設定（スケジュール実行）
resource "google_dataform_repository_release_config" "hourly_aggregation" {
  provider = google-beta
  
  project    = var.project_id
  region     = var.region
  repository = google_dataform_repository.sensor_data_transformation.name
  name       = "hourly-aggregation"

  git_commitish = "main"
  cron_schedule = "0 * * * *"  # 毎時0分に実行
  time_zone     = "Asia/Tokyo"

  code_compilation_config {
    default_database = var.project_id
    default_schema   = google_bigquery_dataset.sensor_data.dataset_id
    default_location = var.region
  }
}

# Dataformサービスアカウントの権限設定
# BigQuery Job User (クエリ実行権限)
resource "google_project_iam_member" "dataform_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [google_project_service.dataform]
}

# BigQuery Data Editor (データ編集権限)
resource "google_bigquery_dataset_iam_member" "dataform_data_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [google_project_service.dataform]
}

