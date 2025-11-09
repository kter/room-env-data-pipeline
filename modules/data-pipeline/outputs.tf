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

