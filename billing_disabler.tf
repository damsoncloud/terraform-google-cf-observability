# The billing disabler (https://github.com/damsoncloud/gcp.billing-disabler), invoked by the budget notifications of the projects enabling it in cf-gcp-project
locals {
  billing_disabler_name                       = "${local.common_short_name}-cf-billing-disabler"
  billing_disabler_timeout_seconds            = 60
  billing_disabler_message_retention_duration = "1800s"
  billing_disabler_readme                     = "https://github.com/damsoncloud/gcp.billing-disabler#readme"
}

resource "google_pubsub_topic" "billing_disabler" {
  project = google_project_service.observability["pubsub.googleapis.com"].project
  name    = local.billing_disabler_name
}

resource "google_service_account" "billing_disabler_invoker" {
  project      = var.observability_project_id
  account_id   = "billing-disabler-invoker"
  display_name = "Billing disabler invoker"
  description  = "Invokes the billing disabler's Cloud Run service with the budget notifications pushed by the ${local.billing_disabler_name} subscription."
}

# Attaching the service accounts to the Cloud Run service and the push subscription requires acting as them; cf-organization grants it on the runner
resource "google_service_account_iam_member" "billing_disabler_invoker_deployer" {
  service_account_id = google_service_account.billing_disabler_invoker.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.tf_bootstrap_email}"
}

# The grant is not effective immediately
resource "time_sleep" "billing_disabler_invoker_deployer_propagation" {
  create_duration = "60s"

  triggers = {
    member = google_service_account_iam_member.billing_disabler_invoker_deployer.member
  }
}

resource "google_cloud_run_v2_service" "billing_disabler" {
  project     = google_project_service.observability["run.googleapis.com"].project
  name        = local.billing_disabler_name
  location    = var.region
  description = "Billing disabler"
  ingress     = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  deletion_protection = false

  scaling {
    min_instance_count = 0
    max_instance_count = 1
  }

  template {
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN1"
    timeout                          = "${local.billing_disabler_timeout_seconds}s"
    service_account                  = var.billing_disabler_email
    max_instance_request_concurrency = 10

    containers {
      name  = "billing-disabler"
      image = "${var.billing_disabler_image_path}:${var.billing_disabler_image_tag}"

      resources {
        limits = {
          cpu    = 1
          memory = "256Mi"
        }
        cpu_idle = true
      }

      env {
        name  = "DRY_RUN"
        value = tostring(var.billing_disabler_dry_run)
      }
    }
  }

  timeouts {
    create = "3m"
    update = "3m"
  }
}

resource "google_cloud_run_v2_service_iam_member" "billing_disabler_invoker" {
  project  = google_cloud_run_v2_service.billing_disabler.project
  location = google_cloud_run_v2_service.billing_disabler.location
  name     = google_cloud_run_v2_service.billing_disabler.name
  role     = "roles/run.invoker"
  member   = google_service_account.billing_disabler_invoker.member
}

resource "google_pubsub_subscription" "billing_disabler" {
  project = google_pubsub_topic.billing_disabler.project
  name    = local.billing_disabler_name
  topic   = google_pubsub_topic.billing_disabler.id

  ack_deadline_seconds       = local.billing_disabler_timeout_seconds * 2
  message_retention_duration = local.billing_disabler_message_retention_duration

  expiration_policy {
    ttl = ""
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  push_config {
    push_endpoint = google_cloud_run_v2_service.billing_disabler.uri

    oidc_token {
      service_account_email = google_service_account.billing_disabler_invoker.email
    }
  }

  depends_on = [time_sleep.billing_disabler_invoker_deployer_propagation]
}

# Log-based alerting policies scan the service's entries, which originate in the Observability project and are routed back to it by the organisation-level sink
locals {
  billing_disabler_alerts = {
    billing_disabled = {
      title                 = "billing disabled"
      severity              = "CRITICAL"
      filter                = "jsonPayload.event=\"billing_disabled\""
      notify_billing_admins = true
      content               = <<-EOT
        # Billing disabled for project `$${log.extracted_label.project_id}`

        The billing disabler detached project `$${log.extracted_label.project_id}` from its billing account and denied all its services, because budget
        `$${log.extracted_label.budget_display_name}` was exceeded.

        To restore the project, follow the Recovery steps in the [billing disabler documentation](${local.billing_disabler_readme}).
      EOT
    }
    billing_disabling_simulated = {
      title                 = "billing disabling simulated"
      severity              = "WARNING"
      filter                = "jsonPayload.event=\"billing_disabling_simulated\""
      notify_billing_admins = true
      content               = <<-EOT
        # Billing disabling simulated for project `$${log.extracted_label.project_id}`

        In dry-run mode, the billing disabler would have disabled billing for project `$${log.extracted_label.project_id}`, because budget
        `$${log.extracted_label.budget_display_name}` was exceeded. No changes were made.

        See the [billing disabler documentation](${local.billing_disabler_readme}).
      EOT
    }
    errors = {
      title                 = "errors"
      severity              = "ERROR"
      filter                = "jsonPayload.event=(\"billing_disabling_failed\" OR \"notification_discarded\")"
      notify_billing_admins = false
      content               = <<-EOT
        # Billing disabler error: `$${log.extracted_label.event}`

        - `billing_disabling_failed`: disabling billing failed for project `$${log.extracted_label.project_id}`. The notification is redelivered until it succeeds.
          Check the error in the log entry, e.g. missing permissions of the function's service account.
        - `notification_discarded`: the notification was invalid or its budget is not scoped to projects, so it is not retried. Check the budget's configuration.

        See the [billing disabler documentation](${local.billing_disabler_readme}).
      EOT
    }
    unhandled_errors = {
      title    = "unhandled errors"
      severity = "ERROR"
      # Request logs repeat each failed invocation, and BillingDisablingError follows `billing_disabling_failed`, which has its own alert
      filter                = "severity>=ERROR AND NOT jsonPayload.event:* AND NOT log_id(\"run.googleapis.com/requests\") AND NOT jsonPayload.exception:\"BillingDisablingError\""
      notify_billing_admins = false
      content               = <<-EOT
        # Billing disabler unhandled error

        The function logged an error not handled by it: `$${log.extracted_label.message}`, `$${log.extracted_label.error}`.

        It may be e.g. a budget which cannot be read, missing permissions of the function's service account or a crashed instance. Notifications failing this way
        are redelivered until they succeed or their retention expires, and billing is not disabled meanwhile. Check the log entries of the Cloud Run service and
        fix the cause.

        See the [billing disabler documentation](${local.billing_disabler_readme}).
      EOT
    }
  }
}

resource "google_monitoring_alert_policy" "billing_disabler" {
  for_each = local.billing_disabler_alerts

  project      = var.observability_project_id
  display_name = "[${var.domain}] ${local.billing_disabler_name} - ${each.value.title}"
  user_labels  = var.labels
  severity     = each.value.severity
  combiner     = "OR"

  documentation {
    mime_type = "text/markdown"
    content   = each.value.content
  }

  notification_channels = concat(
    [google_monitoring_notification_channel.sres.id],
    each.value.notify_billing_admins ? [var.billing_notification_channel] : [],
  )

  conditions {
    display_name = "Billing disabler ${each.value.title}"

    condition_matched_log {
      filter = join(" AND ", [
        "resource.type=\"cloud_run_revision\"",
        "resource.labels.service_name=\"${google_cloud_run_v2_service.billing_disabler.name}\"",
        "(${each.value.filter})",
      ])
      label_extractors = {
        "budget_display_name" = "EXTRACT(jsonPayload.budget_display_name)"
        "error"               = "REGEXP_EXTRACT(jsonPayload.exception, \"(.+)$\")"
        "event"               = "EXTRACT(jsonPayload.event)"
        "message"             = "EXTRACT(jsonPayload.message)"
        "project_id"          = "EXTRACT(jsonPayload.project_id)"
      }
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "600s"
    }
    auto_close = local.billing_disabler_message_retention_duration
  }
}
