output "dataset" {
  description = "ID of the dataset (`projects/<project>/datasets/<dataset>`), selected as the destination of the export in the Google Workspace admin console."
  value       = "projects/${google_bigquery_dataset.drive_inventory.project}/datasets/${google_bigquery_dataset.drive_inventory.dataset_id}"
}
