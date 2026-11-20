variable "organization_id" {
  description = "ID of the organisation, whose logs are routed to the Observability project."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.organization_id))
    error_message = "The organization_id must be the numeric organisation ID."
  }
}

variable "domain" {
  description = "Domain of the organisation's groups, e.g. `example.com` for `gcp-cmn-sres@example.com`. It prefixes the alerting policies' names, to tell apart the alerts of several organisations."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.domain))
    error_message = "The domain must be a lowercase domain name, e.g. `example.com`."
  }
}

variable "folders" {
  description = "The folders by folder name, e.g. the `folders` output of cf-hierarchy: `id`, the resource name (`folders/<id>`); `short_name`, the environment's short name, null for folders other than environments; `common`, whether it is the common environment. The common environment's short name prefixes the resources' names (`<common short name>-cf-observability`) and names its groups."
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
  description = "Email of the `tf-bootstrap` service account applying the module, e.g. the `tf_bootstrap_email` output of cf-bootstrap, granted the Service Account User role on the service accounts the module attaches to resources."
  type        = string
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
  description = "Exclusions of the organisation-level log sink by name: `filter`, the logs not routed to the Observability project; `description`."
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

variable "vpc_service_controls" {
  description = "The VPC Service Controls perimeter around the Observability project, to which the ingress rule of the organisation-level log sink is added; not added when null: `perimeter_name`, the perimeter's resource name, e.g. the `perimeter_name` output of cf-organization's vpc-service-controls submodule; `mode`, the submodule's mode: the rule is added to the dry-run configuration, and to the enforced one too when `enforced`."
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
  description = "Alerts on security-relevant audit log entries of the whole organisation, by a key of lowercase letters, digits and underscores, notified to the common environment's SREs group: `display_name`; `filter`, the Logging query of the entries; `severity`, `CRITICAL`, `ERROR` or `WARNING`; `description`, the alert's guidance. The defaults alert on changes of the organisation and folder IAM policies, on the creation or upload of service account keys, and on changes of organisation policies and custom constraints, attempts denied included."
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

variable "scc_notifications" {
  description = "Email notifications of the organisation's Security Command Centre findings to the common environment's SREs group ([`modules/scc-notifications`](modules/scc-notifications)); not set up when null, e.g. when the findings reach a SIEM: `location`, the Security Command Centre location, `eu`, `sa` or `us` with data residency, `global` otherwise; `severities`, those of the notified active and unmuted findings."
  type = object({
    location   = optional(string, "eu")
    severities = optional(list(string), ["CRITICAL", "HIGH"])
  })
  default = {}

  validation {
    condition     = var.scc_notifications == null || contains(["eu", "global", "sa", "us"], try(var.scc_notifications.location, ""))
    error_message = "The scc_notifications location must be eu, sa, us or global."
  }

  validation {
    condition     = var.scc_notifications == null || try(length(var.scc_notifications.severities) > 0 && length(setsubtract(var.scc_notifications.severities, ["CRITICAL", "HIGH", "MEDIUM", "LOW"])) == 0, false)
    error_message = "The scc_notifications severities must be CRITICAL, HIGH, MEDIUM or LOW, at least one."
  }
}
