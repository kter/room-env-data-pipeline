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

