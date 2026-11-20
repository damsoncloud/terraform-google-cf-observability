module "scc_notifications" {
  source = "./modules/scc-notifications"
  count  = var.scc_notifications == null ? 0 : 1

  organization_id       = var.organization_id
  project_id            = var.observability_project_id
  region                = var.region
  name                  = "${local.name_prefix}-scc-findings"
  scc_location          = var.scc_location
  severities            = var.scc_notifications.severities
  deployer_email        = var.tf_bootstrap_email
  alert_display_name    = "[${var.domain}] ${local.name_prefix} - Security Command Centre finding"
  notification_channels = [google_monitoring_notification_channel.sres.id]
}

module "azure_integration" {
  source = "./modules/azure-integration"
  count  = var.azure_integration == null ? 0 : 1

  organization_id    = var.organization_id
  project_id         = var.observability_project_id
  project_number     = data.google_project.observability.number
  region             = var.region
  tenant_id          = var.azure_integration.tenant_id
  scc_location       = var.scc_location
  sentinel           = var.azure_integration.sentinel
  defender_for_cloud = var.azure_integration.defender_for_cloud
}

module "drive_inventory_export" {
  source = "./modules/drive-inventory-export"
  count  = var.drive_inventory_export == null ? 0 : 1

  project_id      = var.observability_project_id
  region          = var.region
  dataset_id      = replace("${local.common_short_name}-cf-drive-inventory", "-", "_")
  service_account = var.drive_inventory_export.service_account
}
