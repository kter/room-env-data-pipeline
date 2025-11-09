terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  # バックエンド設定（必要に応じてCloud Storageなどを設定）
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "env/prd"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Webhook Function モジュール
module "webhook_function" {
  source = "../../modules/webhook-function"

  project_id     = var.project_id
  region         = var.region
  environment    = var.environment
  
  max_instance_count = var.max_instance_count
  min_instance_count = var.min_instance_count
  memory             = var.memory
  timeout_seconds    = var.timeout_seconds
  
  environment_variables = var.environment_variables
}

