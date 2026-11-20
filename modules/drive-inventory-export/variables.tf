variable "project_id" {
  description = "ID of the project of the dataset, e.g. the Observability project."
  type        = string
}

variable "region" {
  description = "Location of the dataset."
  type        = string
}

variable "dataset_id" {
  description = "ID of the dataset."
  type        = string
}

variable "service_account" {
  description = "Email of the Google Workspace service account exporting the Drive inventory, shown in the Google Workspace admin console."
  type        = string
}
