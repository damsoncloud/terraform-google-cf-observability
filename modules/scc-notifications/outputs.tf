output "topic" {
  description = "ID of the topic the findings are published to (`projects/<project>/topics/<name>`)."
  value       = google_pubsub_topic.scc_notifications.id
}

output "service_agent" {
  description = "Service agent publishing the findings to the topic, e.g. for a VPC Service Controls ingress rule."
  value       = "serviceAccount:${google_scc_v2_organization_notification_config.scc_notifications.service_account}"
}
