output "sensors_export_service_account" {
  value       = google_service_account.sensors_export.email
}
output "sensors_export_bigquery_dataset" {
    value = google_bigquery_dataset.sensors_data_exports.id
}
output "sensors_beagle_fusion_schemas_bucket" {
    value = google_storage_bucket.sensors_beagle_fusion_schemas.name
}
output "sensors_beagle_fusion_validation_bucket" {
    value = google_storage_bucket.sensors_beagle_fusion_validation.name
}
output "sensors_dataflow_flex_templates_bucket" {
    value = google_storage_bucket.sensors_dataflow_flex_templates.name
}
output "sensors_csv_export_bucket" {
    value = google_storage_bucket.sensors_csv_exports.name
}