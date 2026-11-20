output "log_bucket" {
  description = "ID of the centralised logging bucket."
  value       = module.observability.log_bucket
}

output "billing_disabler_topic" {
  description = "ID of the billing disabler's topic, connected to the budgets of the projects enabling the billing disabler."
  value       = module.observability.billing_disabler_topic
}

output "scc_notifications_topic" {
  description = "ID of the topic the Security Command Centre findings are published to."
  value       = module.observability.scc_notifications_topic
}
