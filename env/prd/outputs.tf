output "webhook_url" {
  description = "WebhookのURL"
  value       = module.webhook_function.function_url
}

output "function_name" {
  description = "Cloud Function名"
  value       = module.webhook_function.function_name
}

output "service_account_email" {
  description = "サービスアカウントのメールアドレス"
  value       = module.webhook_function.service_account_email
}

output "pubsub_topic_name" {
  description = "Pub/Subトピック名"
  value       = module.data_pipeline.pubsub_topic_name
}

output "bigquery_dataset_id" {
  description = "BigQueryデータセットID"
  value       = module.data_pipeline.bigquery_dataset_id
}

output "bigquery_raw_table_full_id" {
  description = "BigQuery生データテーブルの完全なID"
  value       = module.data_pipeline.bigquery_raw_table_id
}

output "dataform_repository_name" {
  description = "Dataformリポジトリ名"
  value       = module.data_pipeline.dataform_repository_name
}

output "dataform_repository_id" {
  description = "DataformリポジトリのフルID"
  value       = module.data_pipeline.dataform_repository_id
}

output "bigquery_hourly_stats_table_id" {
  description = "BigQuery時間別統計テーブルID"
  value       = module.data_pipeline.bigquery_hourly_stats_table_id
}

output "bigquery_daily_stats_table_id" {
  description = "BigQuery日別統計テーブルID"
  value       = module.data_pipeline.bigquery_daily_stats_table_id
}

output "bigquery_latest_table_id" {
  description = "BigQuery最新データテーブルID"
  value       = module.data_pipeline.bigquery_latest_table_id
}

