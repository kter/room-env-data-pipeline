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

