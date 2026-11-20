output "dataset" {
  description = "ID of the dataset (`projects/<project>/datasets/<dataset>`), selected as the destination of the export in the Google Workspace admin console."
  value       = google_bigquery_dataset.drive_inventory.id
}
