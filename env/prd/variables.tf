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
  default     = "prd"
}

variable "max_instance_count" {
  description = "Cloud Functionsの最大インスタンス数"
  type        = number
  default     = 20
}

variable "min_instance_count" {
  description = "Cloud Functionsの最小インスタンス数"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Cloud Functionsのメモリ容量"
  type        = string
  default     = "512Mi"
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
    ENVIRONMENT = "production"
  }
}

variable "bigquery_owner_email" {
  description = "BigQueryデータセットのオーナーメールアドレス"
  type        = string
}

variable "table_expiration_days" {
  description = "テーブルの有効期限（日数）。0の場合は無期限"
  type        = number
  default     = 0  # prd環境では無期限が一般的
}

variable "dataform_git_repository_url" {
  description = "Dataform用GitリポジトリのURL"
  type        = string
  default     = ""
}

variable "dataform_git_token_secret_version" {
  description = "GitHub Personal Access TokenのSecret ManagerバージョンID"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub Personal Access Token（TF_VAR_github_tokenで設定）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dataform_git_branch" {
  description = "Dataformと同期するGitブランチ（prd環境: main推奨）"
  type        = string
  default     = "main"  # prd環境ではmainブランチを使用
}

