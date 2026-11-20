variable "organization_id" {
  description = "ID of the organisation."
  type        = string
}

variable "domain" {
  description = "Domain of the organisation's groups."
  type        = string
}

variable "billing_account" {
  description = "ID of the billing account."
  type        = string
}

variable "mode" {
  description = "Mode of the organisation policies and the perimeter, including the ingress rules of cf-observability: `dry_run` first, then `enforced`."
  type        = string
  default     = "dry_run"
}

variable "azure_tenant_id" {
  description = "ID of the Microsoft Entra ID tenant of Microsoft Sentinel and Defender for Cloud."
  type        = string
}

variable "drive_inventory_service_account" {
  description = "Email of the Google Workspace service account exporting the Drive inventory, shown in the Google Workspace admin console."
  type        = string
}
