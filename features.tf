module "scc_notifications" {
  source = "./modules/scc-notifications"
  count  = var.scc_notifications == null ? 0 : 1

  organization_id       = var.organization_id
  project_id            = var.observability_project_id
  region                = var.region
  name                  = "${local.name_prefix}-scc-findings"
  scc_location          = var.scc_notifications.location
  severities            = var.scc_notifications.severities
  deployer_email        = var.tf_bootstrap_email
  alert_display_name    = "[${var.domain}] ${local.name_prefix} - Security Command Centre finding"
  notification_channels = [google_monitoring_notification_channel.sres.id]
}
