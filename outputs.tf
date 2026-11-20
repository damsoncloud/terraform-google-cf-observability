output "sres_notification_channel" {
  description = "ID of the notification channel of the common environment's SREs group (`projects/<project>/notificationChannels/<id>`)."
  value       = google_monitoring_notification_channel.sres.id
}

output "log_bucket" {
  description = "ID of the centralised logging bucket (`projects/<project>/locations/<region>/buckets/<bucket>`)."
  value       = google_logging_project_bucket_config.observability.id
}

output "log_linked_dataset" {
  description = "ID of the BigQuery dataset linked to the centralised logging bucket."
  value       = google_logging_linked_dataset.observability.link_id
}

output "organization_sink_writer_identity" {
  description = "Writer identity of the organisation-level log sink, which writes the logs into the Observability project."
  value       = google_logging_organization_sink.observability.writer_identity
}

output "scc_notifications_topic" {
  description = "ID of the topic the Security Command Centre findings are published to, e.g. for a further subscription; null when the notifications are not set up."
  value       = one(module.scc_notifications[*].topic)
}

output "billing_disabler_topic" {
  description = "ID of the billing disabler's topic (`projects/<project>/topics/<name>`), to which cf-gcp-project connects the budgets of the projects enabling the billing disabler."
  value       = google_pubsub_topic.billing_disabler.id
}

output "drive_inventory_dataset" {
  description = "ID of the BigQuery dataset receiving the Google Drive inventory export, the export's destination in the Google Workspace admin console; null when not set up."
  value       = one(module.drive_inventory_export[*].dataset)
}

output "azure_workload_identity_pool" {
  description = "Resource name of the Workload Identity pool of the Azure tenant, for the Microsoft Sentinel and Defender for Cloud connectors created in Azure; null when the Azure integration is not set up."
  value       = one(module.azure_integration[*].workload_identity_pool)
}
