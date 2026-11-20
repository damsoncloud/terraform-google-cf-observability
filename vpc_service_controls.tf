locals {
  perimeter_enabled  = var.vpc_service_controls != null
  perimeter_enforced = local.perimeter_enabled && try(var.vpc_service_controls.mode, null) == "enforced"

  # Flows into the perimeter from outside it, by rule title
  perimeter_ingress_rules = !local.perimeter_enabled ? {} : merge(
    {
      "Centralised logging organisation sink" = {
        identities = [google_logging_organization_sink.observability.writer_identity]
        resources  = ["projects/${data.google_project.observability.number}"]
        service    = "logging.googleapis.com"
        method     = "*"
      }
    },
    var.scc_notifications == null ? {} : {
      "Security Command Centre finding notifications" = {
        identities = [module.scc_notifications[0].service_agent]
        resources  = ["projects/${data.google_project.observability.number}"]
        service    = "pubsub.googleapis.com"
        method     = "google.pubsub.v1.Publisher.Publish"
      }
    },
    { for title in local.azure_integration_rule_titles : title => module.azure_integration[0].perimeter_ingress_rules[title] },
    var.drive_inventory_export == null ? {} : {
      "Google Drive inventory export" = {
        identities = ["serviceAccount:${var.drive_inventory_export.service_account}"]
        resources  = ["projects/${data.google_project.observability.number}"]
        service    = "bigquery.googleapis.com"
        method     = "*"
      }
    },
  )

  # Known while planning, unlike the submodule's rules, as for_each requires
  azure_integration_rule_titles = var.azure_integration == null ? [] : concat(
    var.azure_integration.sentinel ? ["Microsoft Sentinel"] : [],
    var.azure_integration.defender_for_cloud != null ? ["Microsoft Defender for Cloud"] : [],
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
    identities = each.value.identities

    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = each.value.resources

    operations {
      service_name = each.value.service

      dynamic "method_selectors" {
        for_each = each.value.service == "*" ? [] : [each.value.method]

        content {
          method = method_selectors.value
        }
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
    identities = each.value.identities

    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = each.value.resources

    operations {
      service_name = each.value.service

      dynamic "method_selectors" {
        for_each = each.value.service == "*" ? [] : [each.value.method]

        content {
          method = method_selectors.value
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
