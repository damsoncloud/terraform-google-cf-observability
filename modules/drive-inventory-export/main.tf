resource "google_bigquery_dataset" "drive_inventory" {
  project     = var.project_id
  dataset_id  = var.dataset_id
  location    = var.region
  description = "Google Drive inventory exported from Google Workspace."
}

resource "google_bigquery_dataset_iam_member" "drive_inventory" {
  project    = google_bigquery_dataset.drive_inventory.project
  dataset_id = google_bigquery_dataset.drive_inventory.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${var.service_account}"
}

resource "google_project_iam_member" "drive_inventory" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${var.service_account}"
}
