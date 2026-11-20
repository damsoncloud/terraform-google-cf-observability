variable "organization_id" {
  description = "ID of the organisation, whose Security Command Centre findings are published for Microsoft Sentinel."
  type        = string
}

variable "project_id" {
  description = "ID of the project of the integration, e.g. the Observability project."
  type        = string
}

variable "project_number" {
  description = "Number of the project, for the VPC Service Controls ingress rules."
  type        = string
}

variable "region" {
  description = "Region of the regional resources, e.g. Defender for Cloud's log hydration bucket."
  type        = string
}

variable "tenant_id" {
  description = "ID of the customer's Microsoft Entra ID tenant, naming the Workload Identity pool."
  type        = string
}

variable "scc_location" {
  description = "Security Command Centre location of the findings published for Microsoft Sentinel: `eu`, `sa` or `us` with data residency, `global` otherwise."
  type        = string
}

variable "sentinel" {
  description = "Whether the Microsoft Sentinel integration is set up."
  type        = bool
}

variable "defender_for_cloud" {
  description = "The organisation-level part of the Microsoft Defender for Cloud integration, e.g. the `defender_for_cloud` output of cf-organization; not set up when null: `service_accounts`, their emails by name; `log_collection_role`, the custom role consuming the audit log subscription."
  type = object({
    service_accounts    = map(string)
    log_collection_role = string
  })
}
