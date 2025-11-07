output "function_url" {
  description = "Cloud FunctionのURL"
  value       = google_cloudfunctions2_function.webhook.url
}

output "function_name" {
  description = "Cloud Function名"
  value       = google_cloudfunctions2_function.webhook.name
}

output "service_account_email" {
  description = "Cloud Functionsのサービスアカウントメールアドレス"
  value       = google_service_account.function_sa.email
}

