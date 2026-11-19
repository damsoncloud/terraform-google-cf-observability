locals {
  perimeter_enabled  = var.vpc_service_controls != null
  perimeter_enforced = local.perimeter_enabled && try(var.vpc_service_controls.mode, null) == "enforced"
}

data "google_project" "observability" {
  project_id = var.observability_project_id
}

# The organisation-level sink writes into the Observability project from outside the perimeter
resource "google_access_context_manager_service_perimeter_ingress_policy" "organization_sink" {
  count = local.perimeter_enforced ? 1 : 0

  perimeter = var.vpc_service_controls.perimeter_name
  title     = "Centralised logging organisation sink"

  ingress_from {
    identities = [google_logging_organization_sink.observability.writer_identity]

    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = ["projects/${data.google_project.observability.number}"]

    operations {
      service_name = "logging.googleapis.com"

      method_selectors {
        method = "*"
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "organization_sink" {
  count = local.perimeter_enabled ? 1 : 0

  perimeter = var.vpc_service_controls.perimeter_name
  title     = "Centralised logging organisation sink"

  ingress_from {
    identities = [google_logging_organization_sink.observability.writer_identity]

    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = ["projects/${data.google_project.observability.number}"]

    operations {
      service_name = "logging.googleapis.com"

      method_selectors {
        method = "*"
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
