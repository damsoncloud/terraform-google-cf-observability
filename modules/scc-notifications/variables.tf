variable "organization_id" {
  description = "ID of the organisation, whose findings are notified."
  type        = string
}

variable "project_id" {
  description = "ID of the project of the topic, the workflow and the alerting policy, e.g. the Observability project."
  type        = string
}

variable "region" {
  description = "Region of the workflow and its trigger."
  type        = string
}

variable "name" {
  description = "Name of the notification config, the topic, the workflow and its trigger."
  type        = string
}

variable "scc_location" {
  description = <<-EOT
  Security Command Centre location of the findings: `eu`, `sa` or `us` with data residency, `global` otherwise.
  The findings are linked in the location's jurisdictional console, e.g. `console.eu.cloud.google.com`.
  EOT
  type        = string
}

variable "severities" {
  description = "Severities of the notified findings."
  type        = list(string)
}

variable "deployer_email" {
  description = "Email of the service account applying the module, e.g. `tf-bootstrap`, granted the Service Account User role on the workflow's service account."
  type        = string
}

variable "alert_display_name" {
  description = "Display name of the alerting policy."
  type        = string
}

variable "notification_channels" {
  description = "Notification channels of the alerting policy (`projects/<project>/notificationChannels/<id>`)."
  type        = list(string)
}
