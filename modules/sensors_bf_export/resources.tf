// Creates the service account for the workflow
resource "google_service_account" "sensors_export" {
  account_id = "sensors-export"
  project    = var.project_id
  description = "Sensors service account used to run Dataflow exports."
}

// PERMISSIONS:
// Grants the service account worker access to start BigQuery jobs
resource "google_project_iam_member" "bq_admin_role" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.sensors_export.email}"
}
// Grants the service account worker access to start Dataflow jobs
resource "google_project_iam_member" "dataflow_admin_role" {
  project = var.project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${google_service_account.sensors_export.email}"
}
// Grants the service account worker access to Dataflow
resource "google_project_iam_member" "dataflow_worker_role" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.sensors_export.email}"
}
// Grants the service account serviceAccountTokenCreator for impersonated creds.
resource "google_project_iam_member" "service_account_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.sensors_export.email}"
}
// Grants the service account "service account user". Flex template launches use
// a different service account.
resource "google_project_iam_member" "service_account_user_role" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.sensors_export.email}"
}
// Grants the service account storage access to the gcs buckets
resource "google_project_iam_member" "storage_admin_role" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.sensors_export.email}"
}

// GCS BUCKETS:
// Creates the GCS bucket for Beagle Fusion Schemas
resource "google_storage_bucket" "sensors_beagle_fusion_schemas" {
  name                        = "${var.project_id}-sensors-beagle-fusion-schemas"
  location                    = "US"
  project                     = var.project_id
  uniform_bucket_level_access = true
}
// Creates the GCS bucket for Beagle Fusion Validation
resource "google_storage_bucket" "sensors_beagle_fusion_validation" {
  name                        = "${var.project_id}-sensors-beagle-fusion-validation"
  location                    = "US"
  project                     = var.project_id
  uniform_bucket_level_access = true
}
// Creates the GCS bucket for DataFlow Flex Templates
resource "google_storage_bucket" "sensors_dataflow_flex_templates" {
  name                        = "${var.project_id}-sensors-dataflow"
  location                    = "US"
  project                     = var.project_id
  uniform_bucket_level_access = true
}
// Creates the GCS bucket for CSV Exports
resource "google_storage_bucket" "sensors_csv_exports" {
  name                        = "${var.project_id}-sensors-csv-exports"
  location                    = "US"
  project                     = var.project_id
  uniform_bucket_level_access = true
}

// BIGQUERY DATASETS:
// Creates a BigQuery Dataset for staging Sensors Export data
resource "google_bigquery_dataset" "sensors_data_exports" {
  dataset_id                  = "sensors_data_exports"
  project                     = var.project_id
  description                 = "This is a test description"
  location                    = "US"
}