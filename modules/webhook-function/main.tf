terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Cloud Functionのソースコードをzipにアーカイブ
data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/function-source"
  output_path = "${path.module}/function-source.zip"
}

# Cloud Storageバケット（Cloud Functionのソースコード格納用）
resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-${var.environment}-function-source"
  location = var.region
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# ソースコードをCloud Storageにアップロード
resource "google_storage_bucket_object" "function_source" {
  name   = "webhook-function-${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_source.output_path
}

# Cloud Functions用のサービスアカウント
resource "google_service_account" "function_sa" {
  account_id   = "${var.environment}-webhook-function-sa"
  display_name = "Service Account for Webhook Function (${var.environment})"
  project      = var.project_id
}

# Cloud Functions (2nd gen)
resource "google_cloudfunctions2_function" "webhook" {
  name        = "${var.environment}-webhook-function"
  location    = var.region
  description = "Webhook receiver function for ${var.environment} environment"
  project     = var.project_id

  build_config {
    runtime     = "python311"
    entry_point = "webhook_handler"
    
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    max_instance_count    = var.max_instance_count
    min_instance_count    = var.min_instance_count
    available_memory      = var.memory
    timeout_seconds       = var.timeout_seconds
    service_account_email = google_service_account.function_sa.email

    environment_variables = var.environment_variables
  }
}

# Cloud Functionに対してパブリックアクセスを許可（Webhookとして利用するため）
resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = google_cloudfunctions2_function.webhook.project
  location       = google_cloudfunctions2_function.webhook.location
  cloud_function = google_cloudfunctions2_function.webhook.name
  
  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# Cloud Run Service（Cloud Functions 2nd genの内部実装）に対してパブリックアクセスを許可
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = google_cloudfunctions2_function.webhook.project
  location = google_cloudfunctions2_function.webhook.location
  service  = google_cloudfunctions2_function.webhook.name
  
  role   = "roles/run.invoker"
  member = "allUsers"
}

