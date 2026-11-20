locals {
  perimeter_enabled  = var.vpc_service_controls != null
  perimeter_enforced = local.perimeter_enabled && try(var.vpc_service_controls.mode, null) == "enforced"

  # Flows into the Observability project from outside the perimeter, by rule title
  perimeter_ingress_rules = !local.perimeter_enabled ? {} : merge(
    {
      "Centralised logging organisation sink" = {
        identity = google_logging_organization_sink.observability.writer_identity
        service  = "logging.googleapis.com"
        method   = "*"
      }
    },
    var.scc_notifications == null ? {} : {
      "Security Command Centre finding notifications" = {
        identity = module.scc_notifications[0].service_agent
        service  = "pubsub.googleapis.com"
        method   = "google.pubsub.v1.Publisher.Publish"
      }
    },
  )
}

data "google_project" "observability" {
  project_id = var.observability_project_id
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "rules" {
  for_each = local.perimeter_enforced ? local.perimeter_ingress_rules : {}

  perimeter = var.vpc_service_controls.perimeter_name
  title     = each.key

  ingress_from {
    identities = [each.value.identity]

    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = ["projects/${data.google_project.observability.number}"]

    operations {
      service_name = each.value.service

      method_selectors {
        method = each.value.method
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "rules" {
  for_each = local.perimeter_ingress_rules

  perimeter = var.vpc_service_controls.perimeter_name
  title     = each.key

  ingress_from {
    identities = [each.value.identity]

    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = ["projects/${data.google_project.observability.number}"]

    operations {
      service_name = each.value.service

      method_selectors {
        method = each.value.method
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
