module "hierarchy" {
  source  = "damsoncloud/cf-hierarchy/google"
  version = "0.2.0"

  organization_id = var.organization_id
}

module "bootstrap" {
  source  = "damsoncloud/cf-bootstrap/google"
  version = "0.7.0"

  organization_id = var.organization_id
  folders         = module.hierarchy.folders
  billing_account = var.billing_account
}

module "organization" {
  source  = "damsoncloud/cf-organization/google"
  version = "0.3.0"

  organization_id     = var.organization_id
  domain              = var.domain
  environment_tag_key = module.hierarchy.environment_tag_key_namespaced_name
  folders             = module.hierarchy.folders
  billing_account     = var.billing_account

  bootstrap_project_id            = module.bootstrap.project_id
  tf_bootstrap_email              = module.bootstrap.tf_bootstrap_email
  tf_bootstrap_organization_roles = module.bootstrap.tf_bootstrap_organization_roles
  tf_plan_email                   = module.bootstrap.tf_plan_email
  tf_plan_organization_roles      = module.bootstrap.tf_plan_organization_roles
  tf_environment_emails           = module.bootstrap.tf_environment_emails

  defender_for_cloud = true
}

# Google's and Microsoft's identities granted roles by the Azure integration and the Drive inventory export
module "org_policies" {
  source  = "damsoncloud/cf-organization/google//modules/org-policies"
  version = "0.3.0"

  organization_id            = var.organization_id
  mode                       = var.mode
  allowed_locations          = ["in:europe-west4-locations"]
  legacy_folder_id           = module.hierarchy.folders["legacy"].id
  additional_allowed_members = concat(module.organization.defender_for_cloud.external_members, ["serviceAccount:${var.drive_inventory_service_account}"])
}

module "vpc_service_controls" {
  source  = "damsoncloud/cf-organization/google//modules/vpc-service-controls"
  version = "0.3.0"

  organization_id = var.organization_id
  mode            = var.mode
  projects = {
    bootstrap     = module.bootstrap.project_number
    observability = module.organization.observability_project_number
  }
  deployers = concat(
    [module.bootstrap.tf_bootstrap_email, module.bootstrap.tf_plan_email],
    values(module.bootstrap.tf_environment_emails),
  )
  groups = module.organization.perimeter_groups
}

module "observability" {
  source = "../.."

  organization_id          = var.organization_id
  domain                   = var.domain
  folders                  = module.hierarchy.folders
  observability_project_id = module.organization.observability_project_id
  tf_bootstrap_email       = module.bootstrap.tf_bootstrap_email
  log_retention_days       = 90

  billing_disabler_email       = module.organization.billing_disabler_email
  billing_notification_channel = module.organization.billing_notification_channel
  billing_disabler_dry_run     = true

  # The findings reach Microsoft Sentinel instead of being emailed
  scc_location      = "eu"
  scc_notifications = null
  azure_integration = {
    tenant_id          = var.azure_tenant_id
    sentinel           = true
    defender_for_cloud = module.organization.defender_for_cloud
  }

  drive_inventory_export = {
    service_account = var.drive_inventory_service_account
  }

  vpc_service_controls = {
    perimeter_name = module.vpc_service_controls.perimeter_name
    mode           = var.mode
  }
}
