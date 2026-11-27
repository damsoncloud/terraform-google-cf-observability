variable "organization_id" {
  description = "ID of the organisation, whose logs are routed to the Observability project."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.organization_id))
    error_message = "The organization_id must be the numeric organisation ID."
  }
}

variable "domain" {
  description = <<-EOT
  Domain of the organisation's groups, e.g. `example.com` for `gcp-cmn-sres@example.com`.
  It prefixes the alerting policies' names, to tell apart the alerts of several organisations.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.domain))
    error_message = "The domain must be a lowercase domain name, e.g. `example.com`."
  }
}

variable "folders" {
  description = <<-EOT
  The folders by folder name, e.g. the `folders` output of cf-hierarchy:
    `id`, the resource name (`folders/<id>`);
    `short_name`, the environment's short name, null for folders other than environments;
    `common`, whether it is the common environment.
  The common environment's short name prefixes the resources' names (`<common short name>-cf-observability`) and names its groups.
  EOT
  type = map(object({
    id         = string
    short_name = optional(string)
    common     = optional(bool, false)
  }))

  validation {
    condition     = length([for folder in values(var.folders) : folder if folder.common && folder.short_name != null]) == 1 && length([for folder in values(var.folders) : folder if folder.common]) == 1
    error_message = "Exactly one folder must be the common environment, with a short name."
  }
}

variable "observability_project_id" {
  description = "ID of the Observability project, e.g. the `observability_project_id` output of cf-organization."
  type        = string
}

variable "tf_bootstrap_email" {
  description = <<-EOT
  Email of the `tf-bootstrap` service account applying the module, e.g. the `tf_bootstrap_email` output of cf-bootstrap,
  granted the Service Account User role on the service accounts the module attaches to resources.
  EOT
  type        = string
}

variable "billing_disabler_email" {
  description = <<-EOT
  Email of the billing disabler's service account, running its Cloud Run service, e.g. the `billing_disabler_email` output of cf-organization,
  which grants it its roles and `tf-bootstrap` the Service Account User role on it.
  EOT
  type        = string
}

variable "billing_notification_channel" {
  description = <<-EOT
  ID of the billing administrators' notification channel (`projects/<project>/notificationChannels/<id>`), e.g. the `billing_notification_channel` output of cf-organization,
  notified of the projects whose billing is disabled.
  EOT
  type        = string
}

variable "billing_disabler_image_path" {
  description = "Container image of the billing disabler, without the tag."
  type        = string
  default     = "ghcr.io/damsoncloud/gcp.billing-disabler"
  nullable    = false
}

variable "billing_disabler_image_tag" {
  description = "Tag of the billing disabler's container image, pinned to a reviewed version."
  type        = string
  default     = "1.1.6"
  nullable    = false
}

variable "billing_disabler_dry_run" {
  description = "Whether the billing disabler only logs the projects whose billing it would disable."
  type        = bool
  default     = false
  nullable    = false
}

variable "region" {
  description = "Region of the regional resources, e.g. the centralised logging bucket."
  type        = string
  default     = "europe-west4"
  nullable    = false
}

variable "log_retention_days" {
  description = "Retention of the centralised logging bucket, in days."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 3650
    error_message = "The log_retention_days must be between 1 and 3650."
  }
}

variable "log_exclusions" {
  description = <<-EOT
  Exclusions of the organisation-level log sink by name:
    `filter`, the logs not routed to the Observability project;
    `description`.
  EOT
  type = map(object({
    filter      = string
    description = optional(string)
  }))
  default = {
    apps-script = {
      filter      = "resource.type=\"app_script_function\""
      description = "Excludes the Apps Script logs."
    }
  }
  nullable = false
}

variable "sres_group_suffix" {
  description = "Suffix of the common environment's SREs group (`gcp-<common short name>-<suffix>`), notified of the alerts."
  type        = string
  default     = "sres"
  nullable    = false
}

variable "viewers_group_suffix" {
  description = "Suffix of the common environment's viewers group (`gcp-<common short name>-<suffix>`), which can read all the logs of the centralised logging bucket."
  type        = string
  default     = "viewers"
  nullable    = false
}

variable "labels" {
  description = <<-EOT
  Labels of the alerting policies, following the labelling strategy of the customer design document,
  e.g. the customer repository's default labels, which the provider's `default_labels` do not apply to.
  EOT
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([for key, value in var.labels :
      can(regex("^[\\p{Ll}\\p{Lo}][\\p{Ll}\\p{Lo}\\p{N}_-]{0,62}$", key)) && can(regex("^[\\p{Ll}\\p{Lo}\\p{N}_-]{0,63}$", value))
    ])
    error_message = "Label keys must be 1-63 and values 0-63 lowercase letters, digits, underscores or hyphens, keys starting with a letter, e.g. `team_at_example_com` for an email."
  }
}

variable "vpc_service_controls" {
  description = <<-EOT
  The VPC Service Controls perimeter around the Observability project, to which the ingress rule of the organisation-level log sink is added; not added when null:
    `perimeter_name`, the perimeter's resource name, e.g. the `perimeter_name` output of cf-organization's vpc-service-controls submodule;
    `mode`, the submodule's mode: the rule is added to the dry-run configuration, and to the enforced one too when `enforced`.
  EOT
  type = object({
    perimeter_name = string
    mode           = optional(string, "dry_run")
  })
  default = null

  validation {
    condition     = var.vpc_service_controls == null || can(regex("^accessPolicies/[0-9]+/servicePerimeters/[A-Za-z0-9_]+$", var.vpc_service_controls.perimeter_name))
    error_message = "The perimeter_name must be `accessPolicies/<id>/servicePerimeters/<name>`."
  }

  validation {
    condition     = var.vpc_service_controls == null || contains(["dry_run", "enforced"], try(var.vpc_service_controls.mode, ""))
    error_message = "The mode must be dry_run or enforced."
  }
}

variable "security_alerts" {
  description = <<-EOT
  Alerts on security-relevant audit log entries of the whole organisation, by a key of lowercase letters, digits and underscores,
  notified to the common environment's SREs group:
    `display_name`;
    `filter`, the Logging query of the entries;
    `severity`, `CRITICAL`, `ERROR` or `WARNING`;
    `description`, the alert's guidance.
  The defaults alert on changes of the organisation and folder IAM policies, on the creation or upload of service account keys,
  and on changes of organisation policies and custom constraints, attempts denied included.
  EOT
  type = map(object({
    display_name = string
    filter       = string
    severity     = optional(string, "WARNING")
    description  = optional(string, "")
  }))
  default = {
    organization_iam = {
      display_name = "organisation or folder IAM policy changed"
      filter       = "LOG_ID(\"cloudaudit.googleapis.com/activity\") AND protoPayload.serviceName=\"cloudresourcemanager.googleapis.com\" AND protoPayload.methodName=\"SetIamPolicy\" AND resource.type=(\"organization\" OR \"folder\")"
      description  = "The organisation and folder IAM policies are set authoritatively by the foundations, so a change made otherwise is reverted by their next deployment."
    }
    service_account_keys = {
      display_name = "service account key created"
      filter       = "LOG_ID(\"cloudaudit.googleapis.com/activity\") AND protoPayload.serviceName=\"iam.googleapis.com\" AND protoPayload.methodName=(\"google.iam.admin.v1.CreateServiceAccountKey\" OR \"google.iam.admin.v1.UploadServiceAccountKey\")"
      description  = "Service account keys are long-lived credentials, whose creation is denied by the organisation policies outside the legacy folder."
    }
    organization_policies = {
      display_name = "organisation policy changed"
      filter       = "LOG_ID(\"cloudaudit.googleapis.com/activity\") AND ((protoPayload.serviceName=\"orgpolicy.googleapis.com\" AND protoPayload.methodName=(\"google.cloud.orgpolicy.v2.OrgPolicy.CreatePolicy\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.UpdatePolicy\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.DeletePolicy\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.CreateCustomConstraint\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.UpdateCustomConstraint\" OR \"google.cloud.orgpolicy.v2.OrgPolicy.DeleteCustomConstraint\")) OR (protoPayload.serviceName=\"cloudresourcemanager.googleapis.com\" AND protoPayload.methodName=(\"SetOrgPolicy\" OR \"ClearOrgPolicy\")))"
      description  = "The organisation policies are part of the foundations' security baseline; an unexpected change, or an exception, weakens it."
    }
  }
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.security_alerts) : can(regex("^[a-z][a-z0-9_]*$", key))])
    error_message = "The security_alerts keys must be lowercase letters, digits and underscores, starting with a letter."
  }

  validation {
    condition     = alltrue([for alert in values(var.security_alerts) : contains(["CRITICAL", "ERROR", "WARNING"], alert.severity)])
    error_message = "The security_alerts severities must be CRITICAL, ERROR or WARNING."
  }
}

variable "scc_location" {
  description = <<-EOT
  Security Command Centre location of the organisation's findings, of the email notifications and of the Microsoft Sentinel integration:
  `eu`, `sa` or `us` with data residency, `global` otherwise.
  EOT
  type        = string
  default     = "eu"
  nullable    = false

  validation {
    condition     = contains(["eu", "global", "sa", "us"], var.scc_location)
    error_message = "The scc_location must be eu, sa, us or global."
  }
}

variable "scc_notifications" {
  description = <<-EOT
  Email notifications of the organisation's Security Command Centre findings to the common environment's SREs group
  ([`modules/scc-notifications`](modules/scc-notifications)); not set up when null, e.g. when the findings reach a SIEM:
    `severities`, those of the notified active and unmuted findings.
  EOT
  type = object({
    severities = optional(list(string), ["CRITICAL", "HIGH"])
  })
  default = {}

  validation {
    condition     = var.scc_notifications == null || try(length(var.scc_notifications.severities) > 0 && length(setsubtract(var.scc_notifications.severities, ["CRITICAL", "HIGH", "MEDIUM", "LOW"])) == 0, false)
    error_message = "The scc_notifications severities must be CRITICAL, HIGH, MEDIUM or LOW, at least one."
  }
}

variable "azure_integration" {
  description = <<-EOT
  Microsoft Sentinel and Defender for Cloud integration through Workload Identity Federation from the customer's Microsoft Entra ID tenant
  ([`modules/azure-integration`](modules/azure-integration)); not set up when null:
    `tenant_id`, the tenant's ID;
    `sentinel`, whether Microsoft Sentinel receives the Security Command Centre findings;
    `defender_for_cloud`, the Defender for Cloud integration's organisation-level part, the `defender_for_cloud` output of cf-organization, not set up when null.
  EOT
  type = object({
    tenant_id = string
    sentinel  = optional(bool, false)
    defender_for_cloud = optional(object({
      service_accounts    = map(string)
      log_collection_role = string
    }))
  })
  default = null

  validation {
    condition     = var.azure_integration == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_integration.tenant_id))
    error_message = "The azure_integration tenant_id must be a Microsoft Entra ID tenant ID (GUID)."
  }
}

variable "drive_inventory_export" {
  description = <<-EOT
  Google Drive inventory export from Google Workspace into a BigQuery dataset of the Observability project
  ([`modules/drive-inventory-export`](modules/drive-inventory-export)); not set up when null:
    `service_account`, the email of the Google Workspace service account exporting the inventory, which the org-policies submodule of cf-organization must allow;
    `dataset_id`, the ID of the dataset, generated as `<common short name>_cf_drive_inventory` when null; set it to keep an existing dataset.
  EOT
  type = object({
    service_account = string
    dataset_id      = optional(string)
  })
  default = null

  validation {
    condition     = var.drive_inventory_export == null || can(regex("^[a-z0-9-]+@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.drive_inventory_export.service_account))
    error_message = "The drive_inventory_export service_account must be a service account email."
  }

  validation {
    condition     = try(var.drive_inventory_export.dataset_id == null || (can(regex("^[A-Za-z0-9_]+$", var.drive_inventory_export.dataset_id)) && length(var.drive_inventory_export.dataset_id) <= 1024), true)
    error_message = "The drive_inventory_export dataset_id must be 1-1024 letters, digits or underscores."
  }
}
