output "log_bucket" {
  description = "ID of the centralised logging bucket."
  value       = module.observability.log_bucket
}

output "billing_disabler_topic" {
  description = "ID of the billing disabler's topic, connected to the budgets of the projects enabling the billing disabler."
  value       = module.observability.billing_disabler_topic
}

output "drive_inventory_dataset" {
  description = "ID of the dataset to select as the Drive inventory export's destination in the Google Workspace admin console."
  value       = module.observability.drive_inventory_dataset
}
