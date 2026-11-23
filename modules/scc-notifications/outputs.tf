output "topic" {
  description = "ID of the topic the findings are published to (`projects/<project>/topics/<name>`)."
  value       = google_pubsub_topic.scc_notifications.id
}
