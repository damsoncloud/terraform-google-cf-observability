mock_provider "google" {
  mock_resource "google_logging_organization_sink" {
    defaults = {
      writer_identity = "serviceAccount:service-org-123456789012@gcp-sa-logging.iam.gserviceaccount.com"
    }
  }

  mock_resource "google_logging_project_bucket_config" {
    defaults = {
      id = "projects/cmn-observability-c3d4/locations/europe-west4/buckets/cmn-cf-observability"
    }
  }

  mock_resource "google_logging_project_sink" {
    defaults = {
      writer_identity = "serviceAccount:service-333333333333@gcp-sa-logging.iam.gserviceaccount.com"
    }
  }

  mock_resource "google_pubsub_topic" {
    defaults = {
      id = "projects/cmn-observability-c3d4/topics/cmn-cf-observability-scc-findings"
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      email  = "scc-notifications@cmn-observability-c3d4.iam.gserviceaccount.com"
      member = "serviceAccount:scc-notifications@cmn-observability-c3d4.iam.gserviceaccount.com"
      name   = "projects/cmn-observability-c3d4/serviceAccounts/scc-notifications@cmn-observability-c3d4.iam.gserviceaccount.com"
    }
  }

  mock_data "google_project" {
    defaults = {
      number = "333333333333"
    }
  }

  mock_resource "google_monitoring_notification_channel" {
    defaults = {
      id = "projects/cmn-observability-c3d4/notificationChannels/1234567890"
    }
  }
}

mock_provider "google-beta" {}

mock_provider "time" {}

variables {
  organization_id = "123456789012"
  domain          = "example.com"
  folders = {
    development   = { id = "folders/100000000001", short_name = "dev" }
    certification = { id = "folders/100000000002", short_name = "cert" }
    production    = { id = "folders/100000000003", short_name = "prod" }
    common        = { id = "folders/111111111111", short_name = "cmn", common = true }
    legacy        = { id = "folders/100000000004" }
  }
  observability_project_id     = "cmn-observability-c3d4"
  tf_bootstrap_email           = "tf-bootstrap@cmn-cf-bootstrap-a1b2.iam.gserviceaccount.com"
  billing_disabler_email       = "billing-disabler@cmn-observability-c3d4.iam.gserviceaccount.com"
  billing_notification_channel = "projects/cmn-observability-c3d4/notificationChannels/2222222222"
}

run "organization_sink" {
  assert {
    condition = alltrue([
      google_logging_organization_sink.observability.name == "cmn-cf-observability-project",
      google_logging_organization_sink.observability.org_id == "123456789012",
      google_logging_organization_sink.observability.destination == "logging.googleapis.com/projects/cmn-observability-c3d4",
      google_logging_organization_sink.observability.include_children,
      google_logging_organization_sink.observability.intercept_children,
      google_logging_organization_sink.observability.filter == null,
    ])
    error_message = "The organisation-level sink must route all the logs of the organisation, intercepting them, to the Observability project."
  }

  assert {
    condition = (
      length(google_logging_organization_sink.observability.exclusions) == 1 &&
      google_logging_organization_sink.observability.exclusions[0].name == "apps-script" &&
      google_logging_organization_sink.observability.exclusions[0].filter == "resource.type=\"app_script_function\""
    )
    error_message = "The organisation-level sink must exclude the Apps Script logs by default."
  }

  assert {
    condition = (
      google_project_iam_member.organization_sink.project == "cmn-observability-c3d4" &&
      google_project_iam_member.organization_sink.role == "roles/logging.logWriter" &&
      google_project_iam_member.organization_sink.member == "serviceAccount:service-org-123456789012@gcp-sa-logging.iam.gserviceaccount.com" &&
      output.organization_sink_writer_identity == google_project_iam_member.organization_sink.member
    )
    error_message = "The organisation-level sink's writer identity must be a Logs Writer in the Observability project."
  }
}

run "log_bucket" {
  assert {
    condition = alltrue([
      google_logging_project_bucket_config.observability.project == "cmn-observability-c3d4",
      google_logging_project_bucket_config.observability.bucket_id == "cmn-cf-observability",
      google_logging_project_bucket_config.observability.location == "europe-west4",
      google_logging_project_bucket_config.observability.retention_days == 30,
      google_logging_project_bucket_config.observability.enable_analytics,
    ])
    error_message = "The centralised logging bucket must be in the Observability project's region, with Log Analytics and 30 days retention by default."
  }

  assert {
    condition = (
      google_logging_linked_dataset.observability.link_id == "cmn_cf_observability" &&
      google_logging_linked_dataset.observability.bucket == output.log_bucket &&
      google_logging_linked_dataset.observability.location == "europe-west4"
    )
    error_message = "The linked dataset must be linked to the centralised logging bucket."
  }

  assert {
    condition = (
      google_logging_project_sink.observability.name == "cmn-cf-observability-bucket" &&
      google_logging_project_sink.observability.project == "cmn-observability-c3d4" &&
      google_logging_project_sink.observability.destination == "logging.googleapis.com/${output.log_bucket}" &&
      google_logging_project_sink.observability.filter == null
    )
    error_message = "The project-level sink must route all the logs of the Observability project to the centralised logging bucket."
  }

  assert {
    condition = (
      google_logging_project_sink.default.name == "_Default" &&
      google_logging_project_sink.default.disabled &&
      google_logging_project_sink.default.filter == "NOT LOG_ID(\"cloudaudit.googleapis.com/activity\") AND NOT LOG_ID(\"externalaudit.googleapis.com/activity\") AND NOT LOG_ID(\"cloudaudit.googleapis.com/system_event\") AND NOT LOG_ID(\"externalaudit.googleapis.com/system_event\") AND NOT LOG_ID(\"cloudaudit.googleapis.com/access_transparency\") AND NOT LOG_ID(\"externalaudit.googleapis.com/access_transparency\")"
    )
    error_message = "The Observability project's _Default sink must be disabled, keeping its default filter."
  }

  assert {
    condition = (
      google_logging_log_view_iam_member.viewers.bucket == "cmn-cf-observability" &&
      google_logging_log_view_iam_member.viewers.name == "_AllLogs" &&
      google_logging_log_view_iam_member.viewers.role == "roles/logging.viewAccessor" &&
      google_logging_log_view_iam_member.viewers.member == "group:gcp-cmn-viewers@example.com"
    )
    error_message = "The common environment's viewers must be able to read all the logs of the bucket."
  }
}

run "sink_errors_alert" {
  assert {
    condition = (
      google_logging_metric.sink_errors.filter == "resource.type=logging_sink AND resource.labels.name:cmn-cf-observability AND severity>=ERROR" &&
      google_logging_metric.sink_errors.bucket_name == output.log_bucket
    )
    error_message = "The sink errors metric must count the errors of both sinks in the centralised logging bucket."
  }

  assert {
    condition = (
      google_monitoring_alert_policy.sink_errors.display_name == "[example.com] cmn-cf-observability - logging sinks errors" &&
      google_monitoring_alert_policy.sink_errors.notification_channels == tolist([output.sres_notification_channel])
    )
    error_message = "The sink errors alert must notify the common environment's SREs."
  }

  assert {
    condition     = google_monitoring_notification_channel.sres.labels.email_address == "gcp-cmn-sres@example.com"
    error_message = "The SREs notification channel must email the common environment's SREs group."
  }
}

run "custom_settings" {
  variables {
    region               = "europe-west1"
    log_retention_days   = 400
    log_exclusions       = {}
    sres_group_suffix    = "oncall"
    viewers_group_suffix = "auditors"
    labels               = { component = "cf", owner = "team_at_example_com" }
  }

  assert {
    condition = (
      google_logging_project_bucket_config.observability.location == "europe-west1" &&
      google_logging_project_bucket_config.observability.retention_days == 400 &&
      length(google_logging_organization_sink.observability.exclusions) == 0
    )
    error_message = "The bucket's region and retention and the sink's exclusions must follow the inputs."
  }

  assert {
    condition = (
      google_monitoring_notification_channel.sres.labels.email_address == "gcp-cmn-oncall@example.com" &&
      google_logging_log_view_iam_member.viewers.member == "group:gcp-cmn-auditors@example.com"
    )
    error_message = "The groups must follow the suffix inputs."
  }

  assert {
    condition = (
      google_monitoring_alert_policy.sink_errors.user_labels == tomap({ component = "cf", owner = "team_at_example_com" }) &&
      alltrue([for policy in google_monitoring_alert_policy.billing_disabler : policy.user_labels == tomap({ component = "cf", owner = "team_at_example_com" })]) &&
      alltrue([for policy in google_monitoring_alert_policy.security_alerts : policy.user_labels == tomap({ component = "cf", owner = "team_at_example_com" })])
    )
    error_message = "The alerting policies must be labelled, as the provider's default labels do not apply to them."
  }
}

run "invalid_labels" {
  command = plan

  variables {
    labels = { Owner = "team@example.com" }
  }

  expect_failures = [var.labels]
}

run "no_perimeter" {
  command = plan

  assert {
    condition = (
      length(google_access_context_manager_service_perimeter_ingress_policy.rules) == 0 &&
      length(google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules) == 0
    )
    error_message = "No ingress rule must be added without a perimeter."
  }
}

run "perimeter_dry_run" {
  variables {
    vpc_service_controls = {
      perimeter_name = "accessPolicies/555555555555/servicePerimeters/cloud_foundations_production"
    }
  }

  assert {
    condition = (
      length(google_access_context_manager_service_perimeter_ingress_policy.rules) == 0 &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Centralised logging organisation sink"].perimeter == "accessPolicies/555555555555/servicePerimeters/cloud_foundations_production" &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Centralised logging organisation sink"].ingress_from[0].identities == tolist([output.organization_sink_writer_identity]) &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Centralised logging organisation sink"].ingress_from[0].sources[0].access_level == "*" &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Centralised logging organisation sink"].ingress_to[0].resources == tolist(["projects/333333333333"]) &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Centralised logging organisation sink"].ingress_to[0].operations[0].service_name == "logging.googleapis.com" &&
      toset(keys(google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules)) == toset(["Centralised logging organisation sink"])
    )
    error_message = "In dry-run mode, only the ingress rule of the organisation-level sink into the Observability project must be added, to the dry-run configuration only; the SCC notifications need none."
  }
}

run "perimeter_enforced" {
  variables {
    vpc_service_controls = {
      perimeter_name = "accessPolicies/555555555555/servicePerimeters/cloud_foundations_production"
      mode           = "enforced"
    }
  }

  assert {
    condition = (
      length(google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules) == 1 &&
      length(google_access_context_manager_service_perimeter_ingress_policy.rules) == 1 &&
      google_access_context_manager_service_perimeter_ingress_policy.rules["Centralised logging organisation sink"].ingress_from[0].identities == tolist([output.organization_sink_writer_identity]) &&
      google_access_context_manager_service_perimeter_ingress_policy.rules["Centralised logging organisation sink"].ingress_to[0].resources == tolist(["projects/333333333333"])
    )
    error_message = "In enforced mode, the ingress rule must be added to both configurations."
  }
}

run "invalid_perimeter" {
  command = plan

  variables {
    vpc_service_controls = {
      perimeter_name = "cloud_foundations_production"
      mode           = "enforce"
    }
  }

  expect_failures = [var.vpc_service_controls]
}

run "security_alerts" {
  assert {
    condition     = toset(keys(google_logging_metric.security_alerts)) == toset(["organization_iam", "organization_policies", "service_account_keys"])
    error_message = "The organisation and folder IAM, service account key and organisation policy alerts must be created by default."
  }

  assert {
    condition = alltrue([for key, metric in google_logging_metric.security_alerts : (
      metric.name == "cf/security/${key}" &&
      metric.bucket_name == output.log_bucket &&
      metric.label_extractors["principal"] == "EXTRACT(protoPayload.authenticationInfo.principalEmail)"
    )])
    error_message = "The security metrics must count the entries in the centralised logging bucket, with the principal."
  }

  assert {
    condition     = strcontains(google_logging_metric.security_alerts["organization_iam"].filter, "resource.type=(\"organization\" OR \"folder\")")
    error_message = "The IAM alert must cover the organisation and the folders."
  }

  assert {
    condition = alltrue([for key, policy in google_monitoring_alert_policy.security_alerts : (
      policy.notification_channels == tolist([output.sres_notification_channel]) &&
      policy.severity == "WARNING" &&
      policy.conditions[0].condition_prometheus_query_language[0].query == "{\"logging.googleapis.com/user/cf/security/${key}\"} > 0"
    )])
    error_message = "Each security alert must notify the common environment's SREs when its metric counts an entry."
  }

  assert {
    condition     = google_monitoring_alert_policy.security_alerts["service_account_keys"].display_name == "[example.com] cmn-cf-observability - service account key created"
    error_message = "The security alerts must be named after the domain and the module's prefix."
  }
}

run "custom_security_alerts" {
  command = plan

  variables {
    security_alerts = {
      firewall = {
        display_name = "firewall rule changed"
        filter       = "LOG_ID(\"cloudaudit.googleapis.com/activity\") AND resource.type=\"gce_firewall_rule\""
        severity     = "ERROR"
      }
    }
  }

  assert {
    condition = (
      toset(keys(google_monitoring_alert_policy.security_alerts)) == toset(["firewall"]) &&
      google_monitoring_alert_policy.security_alerts["firewall"].severity == "ERROR"
    )
    error_message = "The security alerts must follow the input."
  }
}

run "invalid_security_alert" {
  command = plan

  variables {
    security_alerts = {
      "Firewall" = { display_name = "firewall", filter = "resource.type=\"gce_firewall_rule\"", severity = "HIGH" }
    }
  }

  expect_failures = [var.security_alerts, var.security_alerts]
}

run "scc_notifications" {
  assert {
    condition = (
      module.scc_notifications[0].topic == output.scc_notifications_topic &&
      output.scc_notifications_topic == "projects/cmn-observability-c3d4/topics/cmn-cf-observability-scc-findings"
    )
    error_message = "The SCC notifications must be set up by default."
  }
}

run "scc_notifications_submodule" {
  command = plan

  module {
    source = "./modules/scc-notifications"
  }

  variables {
    project_id            = "cmn-observability-c3d4"
    region                = "europe-west4"
    name                  = "cmn-cf-observability-scc-findings"
    scc_location          = "eu"
    severities            = ["CRITICAL", "HIGH"]
    deployer_email        = "tf-bootstrap@cmn-cf-bootstrap-a1b2.iam.gserviceaccount.com"
    alert_display_name    = "[example.com] cmn-cf-observability - Security Command Centre finding"
    notification_channels = ["projects/cmn-observability-c3d4/notificationChannels/1234567890"]
    labels                = { component = "cf" }
  }

  assert {
    condition = (
      google_scc_v2_organization_notification_config.scc_notifications.organization == "123456789012" &&
      google_scc_v2_organization_notification_config.scc_notifications.location == "eu" &&
      google_scc_v2_organization_notification_config.scc_notifications.streaming_config[0].filter == "state=\"ACTIVE\" AND NOT mute=\"MUTED\" AND NOT launch_state=\"LAUNCH_STATE_DEPRECATED\" AND (severity=\"CRITICAL\" OR severity=\"HIGH\")"
    )
    error_message = "The organisation's active, unmuted critical and high findings in the eu location must be published."
  }

  assert {
    condition     = strcontains(google_workflows_workflow.scc_notifications.source_contents, "https://console.eu.cloud.google.com/security/command-center/findingsv2;name=")
    error_message = "The findings in the eu location must be linked in the eu jurisdictional console."
  }

  assert {
    condition = (
      google_service_account_iam_member.deployer.role == "roles/iam.serviceAccountUser" &&
      google_service_account_iam_member.deployer.member == "serviceAccount:tf-bootstrap@cmn-cf-bootstrap-a1b2.iam.gserviceaccount.com"
    )
    error_message = "The deployer must be able to attach the workflow's service account."
  }

  assert {
    condition = (
      google_project_service_identity.scc_notifications["workflows.googleapis.com"].project == "cmn-observability-c3d4" &&
      google_project_service_identity.scc_notifications["eventarc.googleapis.com"].project == "cmn-observability-c3d4"
    )
    error_message = "The Workflows and Eventarc service agents must be created before the workflow and the trigger, which need them."
  }

  assert {
    condition = (
      google_monitoring_alert_policy.scc_notifications.notification_channels == tolist(["projects/cmn-observability-c3d4/notificationChannels/1234567890"]) &&
      google_monitoring_alert_policy.scc_notifications.alert_strategy[0].notification_rate_limit[0].period == "300s" &&
      strcontains(google_monitoring_alert_policy.scc_notifications.conditions[0].condition_matched_log[0].filter, "resource.labels.workflow_id=\"cmn-cf-observability-scc-findings\"")
    )
    error_message = "The alerting policy must email the workflow's findings."
  }

  assert {
    condition     = google_monitoring_alert_policy.scc_notifications.user_labels == tomap({ component = "cf" })
    error_message = "The alerting policy must be labelled."
  }
}

run "scc_notifications_global" {
  command = plan

  module {
    source = "./modules/scc-notifications"
  }

  variables {
    project_id            = "cmn-observability-c3d4"
    region                = "europe-west4"
    name                  = "cmn-cf-observability-scc-findings"
    scc_location          = "global"
    severities            = ["CRITICAL"]
    deployer_email        = "tf-bootstrap@cmn-cf-bootstrap-a1b2.iam.gserviceaccount.com"
    alert_display_name    = "SCC"
    notification_channels = []
  }

  assert {
    condition = (
      strcontains(google_workflows_workflow.scc_notifications.source_contents, "https://console.cloud.google.com/security/command-center/findingsv2;name=") &&
      google_scc_v2_organization_notification_config.scc_notifications.streaming_config[0].filter == "state=\"ACTIVE\" AND NOT mute=\"MUTED\" AND NOT launch_state=\"LAUNCH_STATE_DEPRECATED\" AND (severity=\"CRITICAL\")"
    )
    error_message = "The findings in the global location must be linked in the global console."
  }
}

run "no_scc_notifications" {
  command = plan

  variables {
    scc_notifications = null
    vpc_service_controls = {
      perimeter_name = "accessPolicies/555555555555/servicePerimeters/cloud_foundations_production"
    }
  }

  assert {
    condition = (
      length(module.scc_notifications) == 0 &&
      toset(keys(google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules)) == toset(["Centralised logging organisation sink"])
    )
    error_message = "The SCC notifications and their ingress rule must not be set up when disabled."
  }
}

run "invalid_scc_notifications" {
  command = plan

  variables {
    scc_location      = "europe"
    scc_notifications = { severities = ["URGENT"] }
  }

  expect_failures = [var.scc_location, var.scc_notifications]
}

run "billing_disabler" {
  assert {
    condition = (
      google_cloud_run_v2_service.billing_disabler.name == "cmn-cf-billing-disabler" &&
      google_cloud_run_v2_service.billing_disabler.location == "europe-west4" &&
      google_cloud_run_v2_service.billing_disabler.ingress == "INGRESS_TRAFFIC_INTERNAL_ONLY" &&
      google_cloud_run_v2_service.billing_disabler.template[0].service_account == "billing-disabler@cmn-observability-c3d4.iam.gserviceaccount.com" &&
      google_cloud_run_v2_service.billing_disabler.template[0].containers[0].image == "ghcr.io/damsoncloud/gcp.billing-disabler:1.1.6" &&
      one([for env in google_cloud_run_v2_service.billing_disabler.template[0].containers[0].env : env.value if env.name == "DRY_RUN"]) == "false"
    )
    error_message = "The billing disabler must run internally only, as cf-organization's service account, disabling billing by default."
  }

  assert {
    condition = (
      google_pubsub_subscription.billing_disabler.topic == google_pubsub_topic.billing_disabler.id &&
      google_pubsub_subscription.billing_disabler.push_config[0].oidc_token[0].service_account_email == google_service_account.billing_disabler_invoker.email &&
      google_cloud_run_v2_service_iam_member.billing_disabler_invoker.role == "roles/run.invoker" &&
      google_cloud_run_v2_service_iam_member.billing_disabler_invoker.member == google_service_account.billing_disabler_invoker.member &&
      output.billing_disabler_topic == google_pubsub_topic.billing_disabler.id
    )
    error_message = "The budget notifications must be pushed to the billing disabler as its invoker."
  }

  assert {
    condition = (
      google_service_account_iam_member.billing_disabler_invoker_deployer.role == "roles/iam.serviceAccountUser" &&
      google_service_account_iam_member.billing_disabler_invoker_deployer.member == "serviceAccount:tf-bootstrap@cmn-cf-bootstrap-a1b2.iam.gserviceaccount.com"
    )
    error_message = "tf-bootstrap must be able to attach the invoker to the push subscription."
  }

  assert {
    condition = (
      toset(keys(google_monitoring_alert_policy.billing_disabler)) == toset(["billing_disabled", "billing_disabling_simulated", "errors", "unhandled_errors"]) &&
      google_monitoring_alert_policy.billing_disabler["billing_disabled"].notification_channels == tolist([output.sres_notification_channel, "projects/cmn-observability-c3d4/notificationChannels/2222222222"]) &&
      google_monitoring_alert_policy.billing_disabler["errors"].notification_channels == tolist([output.sres_notification_channel]) &&
      strcontains(google_monitoring_alert_policy.billing_disabler["billing_disabled"].conditions[0].condition_matched_log[0].filter, "resource.labels.service_name=\"cmn-cf-billing-disabler\"")
    )
    error_message = "The billing disabler's events must alert the SREs, and the billing administrators of disabled and simulated ones."
  }
}

run "billing_disabler_dry_run" {
  command = plan

  variables {
    billing_disabler_dry_run   = true
    billing_disabler_image_tag = "1.1.5"
  }

  assert {
    condition = (
      one([for env in google_cloud_run_v2_service.billing_disabler.template[0].containers[0].env : env.value if env.name == "DRY_RUN"]) == "true" &&
      google_cloud_run_v2_service.billing_disabler.template[0].containers[0].image == "ghcr.io/damsoncloud/gcp.billing-disabler:1.1.5"
    )
    error_message = "The billing disabler's mode and image must follow the inputs."
  }
}

run "azure_integration" {
  variables {
    azure_integration = {
      tenant_id = "AABBCCDD-1111-2222-3333-444455556666"
      sentinel  = true
      defender_for_cloud = {
        service_accounts = {
          "mdc-ciem-gcp"            = "mdc-ciem-gcp@cmn-observability-c3d4.iam.gserviceaccount.com"
          "mdc-log-collection"      = "mdc-log-collection@cmn-observability-c3d4.iam.gserviceaccount.com"
          "microsoft-defender-cspm" = "microsoft-defender-cspm@cmn-observability-c3d4.iam.gserviceaccount.com"
        }
        log_collection_role = "organizations/123456789012/roles/MicrosoftDefenderForCloudLogCollectionCustomRole"
      }
    }
    vpc_service_controls = {
      perimeter_name = "accessPolicies/555555555555/servicePerimeters/cloud_foundations_production"
    }
  }

  assert {
    condition = (
      output.azure_workload_identity_pool == module.azure_integration[0].workload_identity_pool &&
      toset(keys(google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules)) == toset([
        "Centralised logging organisation sink",
        "Microsoft Sentinel",
        "Microsoft Defender for Cloud",
      ])
    )
    error_message = "The Azure integration's ingress rules must be added to the perimeter."
  }

  assert {
    condition = (
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Microsoft Defender for Cloud"].ingress_to[0].resources == tolist(["*"]) &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Microsoft Defender for Cloud"].ingress_to[0].operations[0].service_name == "*" &&
      length(google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Microsoft Defender for Cloud"].ingress_to[0].operations[0].method_selectors) == 0 &&
      contains(
        google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Microsoft Defender for Cloud"].ingress_from[0].identities,
        "serviceAccount:microsoft-defender-cspm@cmn-observability-c3d4.iam.gserviceaccount.com"
      ) &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Microsoft Sentinel"].ingress_to[0].operations[0].service_name == "pubsub.googleapis.com"
    )
    error_message = "Defender for Cloud must read every project of the perimeter, and Sentinel consume its subscription in the Observability project."
  }
}

run "azure_integration_submodule" {
  module {
    source = "./modules/azure-integration"
  }

  variables {
    project_id     = "cmn-observability-c3d4"
    project_number = "333333333333"
    region         = "europe-west4"
    tenant_id      = "AABBCCDD-1111-2222-3333-444455556666"
    scc_location   = "eu"
    sentinel       = true
    defender_for_cloud = {
      service_accounts = {
        "mdc-ciem-gcp"       = "mdc-ciem-gcp@cmn-observability-c3d4.iam.gserviceaccount.com"
        "mdc-log-collection" = "mdc-log-collection@cmn-observability-c3d4.iam.gserviceaccount.com"
      }
      log_collection_role = "organizations/123456789012/roles/MicrosoftDefenderForCloudLogCollectionCustomRole"
    }
  }

  assert {
    condition     = google_iam_workload_identity_pool.azure.workload_identity_pool_id == "aabbccdd111122223333444455556666"
    error_message = "The Workload Identity pool must be named after the tenant ID, in lowercase and without hyphens."
  }

  assert {
    condition = (
      google_scc_v2_organization_notification_config.sentinel[0].location == "eu" &&
      google_scc_v2_organization_notification_config.sentinel[0].streaming_config[0].filter == "state=\"ACTIVE\" AND NOT mute=\"MUTED\" AND NOT launch_state=\"LAUNCH_STATE_DEPRECATED\"" &&
      google_pubsub_subscription_iam_member.sentinel[0].member == google_service_account.sentinel[0].member
    )
    error_message = "Sentinel must consume all the organisation's active, unmuted findings."
  }

  assert {
    condition = (
      length(google_iam_workload_identity_pool_provider.defender_for_cloud) == 8 &&
      toset([for member in google_service_account_iam_member.defender_for_cloud : member.service_account_id]) == toset([
        "projects/cmn-observability-c3d4/serviceAccounts/mdc-ciem-gcp@cmn-observability-c3d4.iam.gserviceaccount.com",
        "projects/cmn-observability-c3d4/serviceAccounts/mdc-log-collection@cmn-observability-c3d4.iam.gserviceaccount.com",
      ]) &&
      google_pubsub_subscription_iam_member.defender_for_cloud_audit_logs[0].role == "organizations/123456789012/roles/MicrosoftDefenderForCloudLogCollectionCustomRole" &&
      google_pubsub_subscription_iam_member.defender_for_cloud_audit_logs[0].member == "serviceAccount:mdc-log-collection@cmn-observability-c3d4.iam.gserviceaccount.com" &&
      google_logging_project_sink.defender_for_cloud_audit_logs[0].filter == "logName:\"cloudaudit.googleapis.com\"" &&
      google_storage_bucket.defender_for_cloud_log_hydration[0].name == "mdc-log-hydration-cmn-observability-c3d4"
    )
    error_message = "Defender for Cloud's service accounts must be federated, and its audit log subscription and log hydration bucket set up."
  }
}

run "azure_integration_sentinel_only" {
  command = plan

  module {
    source = "./modules/azure-integration"
  }

  variables {
    project_id         = "cmn-observability-c3d4"
    project_number     = "333333333333"
    region             = "europe-west4"
    tenant_id          = "aabbccdd-1111-2222-3333-444455556666"
    scc_location       = "global"
    sentinel           = true
    defender_for_cloud = null
  }

  assert {
    condition = (
      length(google_iam_workload_identity_pool_provider.defender_for_cloud) == 0 &&
      length(google_storage_bucket.defender_for_cloud_log_hydration) == 0 &&
      length(google_scc_v2_organization_notification_config.sentinel) == 1
    )
    error_message = "Only the Sentinel integration must be set up."
  }
}

run "invalid_azure_tenant" {
  command = plan

  variables {
    azure_integration = { tenant_id = "contoso.onmicrosoft.com" }
  }

  expect_failures = [var.azure_integration]
}

run "drive_inventory_export" {
  variables {
    drive_inventory_export = { service_account = "c-123456789012345678901@gcp-sa-statefulreporting.iam.gserviceaccount.com" }
    vpc_service_controls = {
      perimeter_name = "accessPolicies/555555555555/servicePerimeters/cloud_foundations_production"
    }
  }

  assert {
    condition = (
      module.drive_inventory_export[0].dataset == output.drive_inventory_dataset &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Google Drive inventory export"].ingress_from[0].identities == tolist([
        "serviceAccount:c-123456789012345678901@gcp-sa-statefulreporting.iam.gserviceaccount.com",
      ]) &&
      google_access_context_manager_service_perimeter_dry_run_ingress_policy.rules["Google Drive inventory export"].ingress_to[0].operations[0].service_name == "bigquery.googleapis.com"
    )
    error_message = "The Drive inventory export must get its dataset and its ingress rule into the perimeter."
  }
}

run "drive_inventory_export_dataset_id" {
  command = plan

  variables {
    drive_inventory_export = {
      service_account = "c-123456789012345678901@gcp-sa-statefulreporting.iam.gserviceaccount.com"
      dataset_id      = "cmn_europe_west4_drive_inventory"
    }
  }

  assert {
    condition     = output.drive_inventory_dataset == "projects/${var.observability_project_id}/datasets/cmn_europe_west4_drive_inventory"
    error_message = "A given dataset ID must be used, e.g. to keep an existing dataset."
  }
}

run "invalid_drive_inventory_dataset_id" {
  command = plan

  variables {
    drive_inventory_export = {
      service_account = "c-123456789012345678901@gcp-sa-statefulreporting.iam.gserviceaccount.com"
      dataset_id      = "drive-inventory"
    }
  }

  expect_failures = [var.drive_inventory_export]
}

run "drive_inventory_export_submodule" {
  command = plan

  module {
    source = "./modules/drive-inventory-export"
  }

  variables {
    project_id      = "cmn-observability-c3d4"
    region          = "europe-west4"
    dataset_id      = "cmn_cf_drive_inventory"
    service_account = "c-123456789012345678901@gcp-sa-statefulreporting.iam.gserviceaccount.com"
  }

  assert {
    condition = (
      google_bigquery_dataset.drive_inventory.location == "europe-west4" &&
      google_bigquery_dataset_iam_member.drive_inventory.role == "roles/bigquery.dataEditor" &&
      google_project_iam_member.drive_inventory.role == "roles/bigquery.jobUser" &&
      google_project_iam_member.drive_inventory.member == "serviceAccount:c-123456789012345678901@gcp-sa-statefulreporting.iam.gserviceaccount.com"
    )
    error_message = "The export's service account must edit the dataset and run BigQuery jobs."
  }
}

run "no_drive_inventory_export" {
  command = plan

  assert {
    condition     = length(module.drive_inventory_export) == 0 && output.drive_inventory_dataset == null
    error_message = "The Drive inventory export must not be set up by default."
  }
}

run "no_common_folder" {
  command = plan

  variables {
    folders = {
      development = { id = "folders/100000000001", short_name = "dev" }
    }
  }

  expect_failures = [var.folders]
}

run "invalid_retention" {
  command = plan

  variables {
    log_retention_days = 0
  }

  expect_failures = [var.log_retention_days]
}
