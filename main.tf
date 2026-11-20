locals {
  common_short_name = one([for folder in values(var.folders) : folder.short_name if folder.common])
  name_prefix       = "${local.common_short_name}-cf-observability"
  sres_group        = "gcp-${local.common_short_name}-${var.sres_group_suffix}@${var.domain}"
  viewers_group     = "gcp-${local.common_short_name}-${var.viewers_group_suffix}@${var.domain}"
}

resource "google_project_service" "observability" {
  for_each = toset([
    # keep-sorted start
    "bigquery.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    # keep-sorted end
  ])

  project            = var.observability_project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "sres" {
  project      = var.observability_project_id
  display_name = "Common environment Site Reliability Engineers"
  type         = "email"
  labels = {
    email_address = local.sres_group
  }
  force_delete = false
}
