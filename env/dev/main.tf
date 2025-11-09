terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
  
  # バックエンド設定（必要に応じてCloud Storageなどを設定）
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "env/dev"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Data Pipeline モジュール（Pub/Sub, BigQuery）
module "data_pipeline" {
  source = "../../modules/data-pipeline"

  project_id                    = var.project_id
  region                        = var.region
  environment                   = var.environment
  function_service_account_email = module.webhook_function.service_account_email
  bigquery_owner_email          = var.bigquery_owner_email
  table_expiration_days         = var.table_expiration_days
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
  
  environment_variables = merge(
    var.environment_variables,
    {
      PUBSUB_TOPIC = module.data_pipeline.pubsub_topic_id
    }
  )
}

