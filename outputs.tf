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
