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
  description = "環境名"
  type        = string
  default     = "dev"
}

variable "max_instance_count" {
  description = "Cloud Functionsの最大インスタンス数"
  type        = number
  default     = 5
}

variable "min_instance_count" {
  description = "Cloud Functionsの最小インスタンス数"
  type        = number
  default     = 0
}

variable "memory" {
  description = "Cloud Functionsのメモリ容量"
  type        = string
  default     = "256Mi"
}

variable "timeout_seconds" {
  description = "Cloud Functionsのタイムアウト時間（秒）"
  type        = number
  default     = 60
}

variable "environment_variables" {
  description = "環境変数"
  type        = map(string)
  default     = {
    ENVIRONMENT = "development"
  }
}

variable "bigquery_owner_email" {
  description = "BigQueryデータセットのオーナーEmail"
  type        = string
}

variable "table_expiration_days" {
  description = "BigQueryテーブルの保持期間（日数）。0は無期限"
  type        = number
  default     = 0
}

variable "dataform_git_repository_url" {
  description = "DataformのGitリポジトリURL（例: https://github.com/kter/room-env-data-pipeline.git）"
  type        = string
  default     = "https://github.com/kter/room-env-data-pipeline.git"
}

variable "dataform_git_token_secret_version" {
  description = "GitHub Personal Access TokenのSecret ManagerバージョンID"
  type        = string
  default     = ""  # 設定する場合: projects/room-env-data-pipeline-dev/secrets/dataform-github-token/versions/latest
}

