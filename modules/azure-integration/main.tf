locals {
  # Microsoft's Entra ID tenant issuing the tokens of Sentinel and Defender for Cloud, and the IDs of their applications, as Microsoft's onboarding expects
  issuer_uri      = "https://sts.windows.net/33e01921-4d64-4f8c-a055-5bdaffd5e33d"
  sentinel_app_id = "2041288c-b303-4ca0-9076-9612db3beeb2"
  defender_for_cloud_providers = {
    auto-provisioner              = "d17a7d74-7e73-4e7d-bd41-8d9525e86cab"
    cspm                          = "6e81e733-9e7f-474a-85f0-385c097f7f52"
    containers                    = "6610e979-c931-41ec-adc7-b9920c9d52f1"
    containers-streams            = "2041288c-b303-4ca0-9076-9612db3beeb2"
    defender-for-servers          = "AzureSecurityCenter.MultiCloud.DefenderForServers"
    defender-for-databases-arc-ap = "AzureSecurityCenter.MultiCloud.DefenderForServers"
    data-security-posture-storage = "2723a073-e7ed-4ff8-be05-88acda0c702e"
    log-collection                = "2041288c-b303-4ca0-9076-9612db3beeb2"
  }
  defender_for_cloud_ciem_app_id = "5e174513-2037-45d3-9eca-29403f20193f"

  defender_for_cloud = var.defender_for_cloud != null
  sentinel_name      = "microsoft-sentinel"
}

# Named after the customer's Azure tenant, as Microsoft's onboarding expects
resource "google_iam_workload_identity_pool" "azure" {
  project                   = var.project_id
  workload_identity_pool_id = lower(replace(var.tenant_id, "-", ""))
  display_name              = "Azure integration"
}

#
# Microsoft Sentinel
#

resource "google_iam_workload_identity_pool_provider" "sentinel" {
  count = var.sentinel ? 1 : 0

  project                            = google_iam_workload_identity_pool.azure.project
  workload_identity_pool_id          = google_iam_workload_identity_pool.azure.workload_identity_pool_id
  workload_identity_pool_provider_id = local.sentinel_name
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  oidc {
    allowed_audiences = ["api://${local.sentinel_app_id}"]
    issuer_uri        = local.issuer_uri
  }
}

resource "google_service_account" "sentinel" {
  count = var.sentinel ? 1 : 0

  project      = var.project_id
  account_id   = local.sentinel_name
  display_name = "Microsoft Sentinel"
}

resource "google_service_account_iam_member" "sentinel" {
  count = var.sentinel ? 1 : 0

  service_account_id = google_service_account.sentinel[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.azure.name}/*"
}

resource "google_pubsub_topic" "sentinel" {
  count = var.sentinel ? 1 : 0

  project = var.project_id
  name    = "${local.sentinel_name}-scc"
}

resource "google_pubsub_subscription" "sentinel" {
  count = var.sentinel ? 1 : 0

  project = google_pubsub_topic.sentinel[0].project
  name    = google_pubsub_topic.sentinel[0].name
  topic   = google_pubsub_topic.sentinel[0].id

  message_retention_duration = "1200s"
  retain_acked_messages      = false
  ack_deadline_seconds       = 20
}

resource "google_project_iam_custom_role" "sentinel" {
  count = var.sentinel ? 1 : 0

  project     = var.project_id
  role_id     = "SentinelPubSubCustomRole"
  title       = "Sentinel x Pub/Sub Custom Role"
  description = "Consumes the Security Command Centre findings published for Microsoft Sentinel."
  permissions = [
    "pubsub.subscriptions.consume",
    "pubsub.subscriptions.get",
  ]
}

resource "google_pubsub_subscription_iam_member" "sentinel" {
  count = var.sentinel ? 1 : 0

  project      = google_pubsub_subscription.sentinel[0].project
  subscription = google_pubsub_subscription.sentinel[0].name
  role         = google_project_iam_custom_role.sentinel[0].id
  member       = google_service_account.sentinel[0].member
}

# All the active, unmuted findings, unlike the critical and high ones emailed by the scc-notifications submodule
resource "google_scc_v2_organization_notification_config" "sentinel" {
  count = var.sentinel ? 1 : 0

  organization = var.organization_id
  location     = var.scc_location
  config_id    = local.sentinel_name
  description  = "Integration with Microsoft Sentinel through Pub/Sub."
  pubsub_topic = google_pubsub_topic.sentinel[0].id

  streaming_config {
    filter = "state=\"ACTIVE\" AND NOT mute=\"MUTED\" AND NOT launch_state=\"LAUNCH_STATE_DEPRECATED\""
  }
}

#
# Microsoft Defender for Cloud, whose service accounts and organisation roles are created by cf-organization
#

resource "google_iam_workload_identity_pool_provider" "defender_for_cloud" {
  for_each = local.defender_for_cloud ? local.defender_for_cloud_providers : {}

  project                            = google_iam_workload_identity_pool.azure.project
  workload_identity_pool_id          = google_iam_workload_identity_pool.azure.workload_identity_pool_id
  workload_identity_pool_provider_id = each.key
  description                        = each.key
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  oidc {
    allowed_audiences = ["api://${each.value}"]
    issuer_uri        = local.issuer_uri
  }
}

resource "google_iam_workload_identity_pool_provider" "defender_for_cloud_ciem" {
  count = local.defender_for_cloud ? 1 : 0

  project                            = google_iam_workload_identity_pool.azure.project
  workload_identity_pool_id          = google_iam_workload_identity_pool.azure.workload_identity_pool_id
  workload_identity_pool_provider_id = "ciem-gcp"
  description                        = "ciem-gcp"
  attribute_mapping = {
    "google.subject"  = "assertion.sub"
    "attribute.tid"   = "assertion.tid"
    "attribute.appid" = "assertion.appid"
  }

  oidc {
    allowed_audiences = ["api://${local.defender_for_cloud_ciem_app_id}"]
    issuer_uri        = local.issuer_uri
  }
}

resource "google_service_account_iam_member" "defender_for_cloud" {
  for_each = local.defender_for_cloud ? var.defender_for_cloud.service_accounts : {}

  service_account_id = "projects/${var.project_id}/serviceAccounts/${each.value}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.azure.name}/*"
}

# Log hydration of the Cloud Infrastructure Entitlement Management
resource "google_storage_bucket" "defender_for_cloud_log_hydration" {
  count = local.defender_for_cloud ? 1 : 0

  project                     = var.project_id
  name                        = "mdc-log-hydration-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true

  soft_delete_policy {
    retention_duration_seconds = 0
  }
}

resource "google_storage_bucket_iam_member" "defender_for_cloud_log_hydration" {
  for_each = local.defender_for_cloud ? toset(["roles/storage.objectCreator", "roles/storage.objectViewer"]) : toset([])

  bucket = google_storage_bucket.defender_for_cloud_log_hydration[0].name
  role   = each.key
  member = "serviceAccount:${var.defender_for_cloud.service_accounts["mdc-ciem-gcp"]}"
}

resource "google_project_iam_member" "defender_for_cloud_log_hydration" {
  count = local.defender_for_cloud ? 1 : 0

  project = var.project_id
  role    = "roles/logging.configWriter"
  member  = "serviceAccount:${var.defender_for_cloud.service_accounts["mdc-ciem-gcp"]}"
}

# The audit logs of the whole organisation, routed to the project by the organisation-level sink
resource "google_pubsub_topic" "defender_for_cloud_audit_logs" {
  count = local.defender_for_cloud ? 1 : 0

  project = var.project_id
  name    = "MicrosoftDefender-ControlPlane-Topic"
}

resource "google_pubsub_subscription" "defender_for_cloud_audit_logs" {
  count = local.defender_for_cloud ? 1 : 0

  project = google_pubsub_topic.defender_for_cloud_audit_logs[0].project
  name    = "mdc-logging-pub-sub"
  topic   = google_pubsub_topic.defender_for_cloud_audit_logs[0].id
}

resource "google_logging_project_sink" "defender_for_cloud_audit_logs" {
  count = local.defender_for_cloud ? 1 : 0

  project                = var.project_id
  name                   = "MicrosoftDefender-ControlPlane-Sink"
  destination            = "pubsub.googleapis.com/${google_pubsub_topic.defender_for_cloud_audit_logs[0].id}"
  filter                 = "logName:\"cloudaudit.googleapis.com\""
  unique_writer_identity = true
}

resource "google_pubsub_topic_iam_member" "defender_for_cloud_audit_logs" {
  count = local.defender_for_cloud ? 1 : 0

  project = google_pubsub_topic.defender_for_cloud_audit_logs[0].project
  topic   = google_pubsub_topic.defender_for_cloud_audit_logs[0].name
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.defender_for_cloud_audit_logs[0].writer_identity
}

resource "google_pubsub_subscription_iam_member" "defender_for_cloud_audit_logs" {
  count = local.defender_for_cloud ? 1 : 0

  project      = google_pubsub_subscription.defender_for_cloud_audit_logs[0].project
  subscription = google_pubsub_subscription.defender_for_cloud_audit_logs[0].name
  role         = var.defender_for_cloud.log_collection_role
  member       = "serviceAccount:${var.defender_for_cloud.service_accounts["mdc-log-collection"]}"
}
