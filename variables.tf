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
