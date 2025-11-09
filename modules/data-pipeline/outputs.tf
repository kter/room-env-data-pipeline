output "pubsub_topic_name" {
  description = "Pub/Subトピック名"
  value       = google_pubsub_topic.switchbot_events.name
}

output "pubsub_topic_id" {
  description = "Pub/SubトピックID"
  value       = google_pubsub_topic.switchbot_events.id
}

output "bigquery_dataset_id" {
  description = "BigQueryデータセットID"
  value       = google_bigquery_dataset.sensor_data.dataset_id
}

output "bigquery_raw_table_id" {
  description = "BigQuery生データテーブルID"
  value       = google_bigquery_table.sensor_raw_data.table_id
}

output "bigquery_raw_table_full_id" {
  description = "BigQuery生データテーブルのフルID"
  value       = "${var.project_id}.${google_bigquery_dataset.sensor_data.dataset_id}.${google_bigquery_table.sensor_raw_data.table_id}"
}

output "bigquery_hourly_stats_table_id" {
  description = "BigQuery集計テーブルID"
  value       = google_bigquery_table.sensor_hourly_stats.table_id
}

output "subscription_name" {
  description = "BigQuery SubscriptionName"
  value       = google_pubsub_subscription.bigquery_subscription.name
}

output "dlq_topic_name" {
  description = "Dead Letter QueueトピックName"
  value       = google_pubsub_topic.switchbot_events_dlq.name
}

output "dataform_repository_name" {
  description = "Dataformリポジトリ名"
  value       = google_dataform_repository.sensor_data_transformation.name
}

output "dataform_repository_id" {
  description = "DataformリポジトリID"
  value       = google_dataform_repository.sensor_data_transformation.id
}

output "dataform_release_config_name" {
  description = "Dataformリリース設定名"
  value       = google_dataform_repository_release_config.hourly_aggregation.name
}

output "bigquery_daily_stats_table_id" {
  description = "BigQuery日別統計テーブルID"
  value       = google_bigquery_table.sensor_daily_stats.table_id
}

output "bigquery_latest_table_id" {
  description = "BigQuery最新状態テーブルID"
  value       = google_bigquery_table.sensor_latest.table_id
}

