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

variable "max_instance_count" {
  description = "Cloud Functionsの最大インスタンス数"
  type        = number
  default     = 10
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
  default     = {}
}

