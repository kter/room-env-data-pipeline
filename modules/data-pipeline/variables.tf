variable "project_id" {
  description = "GCPプロジェクトID"
  type        = string
}

variable "region" {
  description = "リージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "環境名 (dev, prd)"
  type        = string

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "環境名はdevまたはprdである必要があります。"
  }
}

variable "function_service_account_email" {
  description = "Cloud FunctionsのサービスアカウントEmail"
  type        = string
}

variable "bigquery_owner_email" {
  description = "BigQueryデータセットのオーナーEmail"
  type        = string
}

variable "table_expiration_days" {
  description = "BigQueryテーブルの保持期間（日数）。0は無期限"
  type        = number
  default     = 0 # 無期限（履歴データとして保持）
}

