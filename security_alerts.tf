# Log-based alerting policies cannot scan entries originating in the organisation or folders, nor those routed from other projects by the
# organisation-level sink, so the events are counted by metrics scoped to the centralised logging bucket
resource "google_logging_metric" "security_alerts" {
  for_each = var.security_alerts

  project     = var.observability_project_id
  name        = "cf/security/${each.key}"
  description = "Count of the audit log entries of the '${each.value.display_name}' security alert."
  filter      = each.value.filter
  bucket_name = google_logging_project_bucket_config.observability.id

  metric_descriptor {
    unit         = "1"
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = each.value.display_name

    labels {
      key         = "principal"
      value_type  = "STRING"
      description = "Principal making the call"
    }

    labels {
      key         = "method"
      value_type  = "STRING"
      description = "Method called"
    }

    labels {
      key         = "resource_name"
      value_type  = "STRING"
      description = "Resource the method was called on"
    }
  }

  label_extractors = {
    "method"        = "EXTRACT(protoPayload.methodName)"
    "principal"     = "EXTRACT(protoPayload.authenticationInfo.principalEmail)"
    "resource_name" = "EXTRACT(protoPayload.resourceName)"
  }
}

resource "google_monitoring_alert_policy" "security_alerts" {
  for_each = var.security_alerts

  project      = var.observability_project_id
  display_name = "[${var.domain}] ${local.name_prefix} - ${each.value.display_name}"
  user_labels  = var.labels
  severity     = each.value.severity
  combiner     = "OR"

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      # Security alert - ${each.value.display_name}

      `$${metric.label.principal}` called `$${metric.label.method}` on `$${metric.label.resource_name}`.

      ${each.value.description}

      Changes deployed by the foundations' service accounts are expected; verify them against the deployment. Find the audit log entries in
      the centralised logging bucket `${google_logging_project_bucket_config.observability.id}`.
    EOT
  }

  notification_channels = [google_monitoring_notification_channel.sres.id]

  conditions {
    display_name = each.value.display_name

    condition_prometheus_query_language {
      query               = "{\"logging.googleapis.com/user/${google_logging_metric.security_alerts[each.key].name}\"} > 0"
      duration            = "0s"
      evaluation_interval = "30s"
    }
  }

  alert_strategy {
    notification_prompts = ["OPENED"]
  }

  depends_on = [time_sleep.metrics_propagation]
}
