// Set up GCS Bucket for Alta ingestion and authorize VSBJ with `objetAdmin`.
module "alta_bucket" {
  source = "../../kumo/v5/bucket"

  project_id = var.project_id
  bucket_name = var.bucket_id
  additional_bindings = [{
    role = "roles/storage.objectAdmin"
    members = [var.alta_user]
  }]
}
