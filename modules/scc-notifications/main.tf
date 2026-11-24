locals {
  console_host = var.scc_location == "global" ? "console.cloud.google.com" : "console.${var.scc_location}.cloud.google.com"
  severities   = join(" OR ", [for severity in var.severities : "severity=\"${severity}\""])
}

resource "google_project_service" "scc_notifications" {
  for_each = toset([
    # keep-sorted start
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "workflowexecutions.googleapis.com",
    "workflows.googleapis.com",
    # keep-sorted end
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_pubsub_topic" "scc_notifications" {
  project = google_project_service.scc_notifications["pubsub.googleapis.com"].project
  name    = var.name
}

resource "google_scc_v2_organization_notification_config" "scc_notifications" {
  organization = var.organization_id
  location     = var.scc_location
  config_id    = var.name
  description  = "Active, unmuted findings of the notified severities, emailed by the ${var.name} workflow."
  pubsub_topic = google_pubsub_topic.scc_notifications.id

  streaming_config {
    filter = "state=\"ACTIVE\" AND NOT mute=\"MUTED\" AND NOT launch_state=\"LAUNCH_STATE_DEPRECATED\" AND (${local.severities})"
  }
}

resource "google_service_account" "scc_notifications" {
  project      = var.project_id
  account_id   = "scc-notifications"
  display_name = "SCC finding notifications"
  description  = "Runs the ${var.name} workflow, which logs the SCC findings published to the ${var.name} topic."
}

# Attaching the service account to the workflow and the trigger requires acting as it
resource "google_service_account_iam_member" "deployer" {
  service_account_id = google_service_account.scc_notifications.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.deployer_email}"
}

# The IAM grant is not effective immediately
resource "time_sleep" "deployer_iam_propagation" {
  create_duration = "60s"

  triggers = {
    member = google_service_account_iam_member.deployer.member
  }
}

resource "google_project_iam_member" "scc_notifications" {
  for_each = toset([
    # keep-sorted start
    "roles/eventarc.eventReceiver",
    "roles/logging.logWriter",
    "roles/workflows.invoker",
    # keep-sorted end
  ])

  project = var.project_id
  role    = each.key
  member  = google_service_account.scc_notifications.member
}

resource "google_workflows_workflow" "scc_notifications" {
  project             = google_project_service.scc_notifications["workflows.googleapis.com"].project
  name                = var.name
  region              = var.region
  description         = "Logs the SCC findings published to the ${var.name} topic, with their console URL, for the ${var.name} alerting policy."
  service_account     = google_service_account.scc_notifications.email
  deletion_protection = false

  source_contents = <<-EOT
    main:
      params: [event]
      steps:
        - decode:
            assign:
              - message: $${json.decode(base64.decode(event.data.message.data))}
              - finding: $${message.finding}
        - log:
            call: sys.log
            args:
              severity: WARNING
              json:
                event: scc_finding
                finding_name: $${finding.name}
                category: $${finding.category}
                finding_severity: $${finding.severity}
                resource_name: $${finding.resourceName}
                console_url: $${"https://${local.console_host}/security/command-center/findingsv2;name=" + text.url_encode(finding.name) + "?organizationId=${var.organization_id}"}
  EOT

  depends_on = [time_sleep.deployer_iam_propagation, google_project_service.scc_notifications["workflowexecutions.googleapis.com"]]
}

resource "google_eventarc_trigger" "scc_notifications" {
  project         = google_project_service.scc_notifications["eventarc.googleapis.com"].project
  name            = var.name
  location        = var.region
  service_account = google_service_account.scc_notifications.email

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  destination {
    workflow = google_workflows_workflow.scc_notifications.id
  }

  transport {
    pubsub {
      topic = google_pubsub_topic.scc_notifications.id
    }
  }

  depends_on = [time_sleep.deployer_iam_propagation, google_project_iam_member.scc_notifications]
}

# Log-based alerting policies scan the workflow's entries, which originate in the project and are routed back to it by the organisation-level sink
resource "google_monitoring_alert_policy" "scc_notifications" {
  project      = var.project_id
  display_name = var.alert_display_name
  user_labels  = var.labels
  severity     = "CRITICAL"
  combiner     = "OR"

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      # Security Command Centre $${log.extracted_label.finding_severity} finding: $${log.extracted_label.category}

      Resource: `$${log.extracted_label.resource_name}`

      [Open the finding in Security Command Centre]($${log.extracted_label.console_url})

      Notifications are sent at most once in 5 minutes, so further findings may only be listed in Security Command Centre.
    EOT
  }

  notification_channels = var.notification_channels

  conditions {
    display_name = "Security Command Centre finding"

    condition_matched_log {
      filter = join(" AND ", [
        "resource.type=\"workflows.googleapis.com/Workflow\"",
        "resource.labels.workflow_id=\"${google_workflows_workflow.scc_notifications.name}\"",
        "jsonPayload.event=\"scc_finding\"",
      ])
      label_extractors = {
        "category"         = "EXTRACT(jsonPayload.category)"
        "console_url"      = "EXTRACT(jsonPayload.console_url)"
        "finding_severity" = "EXTRACT(jsonPayload.finding_severity)"
        "resource_name"    = "EXTRACT(jsonPayload.resource_name)"
      }
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "1800s"
  }
}
