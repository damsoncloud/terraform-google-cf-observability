resource "google_logging_organization_sink" "observability" {
  name               = "${local.name_prefix}-project"
  description        = "Routes the logs of the whole organisation to the Observability project, instead of the projects' own log buckets."
  org_id             = var.organization_id
  destination        = "logging.googleapis.com/projects/${var.observability_project_id}"
  include_children   = true
  intercept_children = true

  dynamic "exclusions" {
    for_each = var.log_exclusions

    content {
      name        = exclusions.key
      description = exclusions.value.description
      filter      = exclusions.value.filter
    }
  }
}

resource "google_project_iam_member" "organization_sink" {
  project = var.observability_project_id
  role    = "roles/logging.logWriter"
  member  = google_logging_organization_sink.observability.writer_identity
}

resource "google_logging_project_bucket_config" "observability" {
  project          = google_project_service.observability["logging.googleapis.com"].project
  location         = var.region
  bucket_id        = local.name_prefix
  description      = "Centralised logging bucket of the organisation."
  retention_days   = var.log_retention_days
  enable_analytics = true
}

resource "google_logging_linked_dataset" "observability" {
  link_id     = replace(local.name_prefix, "-", "_")
  description = "Centralised logging bucket of the organisation."
  parent      = "projects/${google_project_service.observability["bigquery.googleapis.com"].project}"
  location    = var.region
  bucket      = google_logging_project_bucket_config.observability.id
}

# The bucket is in the sink's project, so the writer identity needs no grant
resource "google_logging_project_sink" "observability" {
  name                   = "${local.name_prefix}-bucket"
  description            = "Routes the logs of the organisation, routed to the Observability project, to the centralised logging bucket."
  project                = var.observability_project_id
  destination            = "logging.googleapis.com/${google_logging_project_bucket_config.observability.id}"
  unique_writer_identity = true
}

# Disabled so that the logs routed to the project are stored only in the centralised logging bucket; the provider adopts the existing sink and
# leaves it unchanged on destroy
resource "google_logging_project_sink" "default" {
  name        = "_Default"
  project     = var.observability_project_id
  destination = "logging.googleapis.com/projects/${var.observability_project_id}/locations/global/buckets/_Default"
  filter = join(" AND ", [
    for log_id in [
      "cloudaudit.googleapis.com/activity",
      "externalaudit.googleapis.com/activity",
      "cloudaudit.googleapis.com/system_event",
      "externalaudit.googleapis.com/system_event",
      "cloudaudit.googleapis.com/access_transparency",
      "externalaudit.googleapis.com/access_transparency",
    ] : "NOT LOG_ID(\"${log_id}\")"
  ])
  disabled = true
}

# Monitoring

resource "google_logging_log_view_iam_member" "viewers" {
  parent   = "projects/${var.observability_project_id}"
  location = var.region
  bucket   = google_logging_project_bucket_config.observability.bucket_id
  name     = "_AllLogs"
  role     = "roles/logging.viewAccessor"
  member   = "group:${local.viewers_group}"
}

resource "google_logging_metric" "sink_errors" {
  project     = var.observability_project_id
  name        = "cf/centralised_logging/logging_sink_errors"
  description = "Count of the centralised logging sinks' errors."
  filter      = "resource.type=logging_sink AND resource.labels.name:${local.name_prefix} AND severity>=ERROR"
  bucket_name = google_logging_project_bucket_config.observability.id

  metric_descriptor {
    unit         = "1"
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = "Error log entries count"

    labels {
      key         = "sink_name"
      value_type  = "STRING"
      description = "Name of the affected logging sink"
    }

    labels {
      key         = "destination"
      value_type  = "STRING"
      description = "Destination of the affected logging sink"
    }
  }

  label_extractors = {
    "destination" = "EXTRACT(resource.labels.destination)"
    "sink_name"   = "EXTRACT(resource.labels.name)"
  }
}

# A new metric is not available to alerting policies immediately; replaced, and so waits again, when a metric is added
resource "time_sleep" "metrics_propagation" {
  create_duration = "60s"

  triggers = {
    metrics = join(",", concat([google_logging_metric.sink_errors.id], [for metric in google_logging_metric.security_alerts : metric.id]))
  }
}

resource "google_monitoring_alert_policy" "sink_errors" {
  project      = var.observability_project_id
  display_name = "[${var.domain}] ${local.name_prefix} - logging sinks errors"
  severity     = "WARNING"
  combiner     = "OR"

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      # Centralised logging - errors detected

      Errors detected for the `$${metric.label.sink_name}` logging sink.

      To troubleshoot, first analyse the error log entry to determine the course of action. The possible causes are:

      - The log sink or its destination does not exist.
      - The writer identity of the organisation-level log sink cannot write logs into the Observability project.
    EOT
  }

  notification_channels = [google_monitoring_notification_channel.sres.id]

  conditions {
    display_name = "Logging sinks errors detected"

    condition_prometheus_query_language {
      query               = "{\"logging.googleapis.com/user/${google_logging_metric.sink_errors.name}\", \"monitored_resource_type\"=\"logging_sink\"} > 0"
      duration            = "0s"
      evaluation_interval = "30s"
    }
  }

  alert_strategy {
    notification_prompts = ["OPENED"]
  }

  depends_on = [time_sleep.metrics_propagation]
}
