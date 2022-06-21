variable "project_id" {
  description = "The GCP project ID to configure."
  type        = string
}
variable "bucket_id" {
  description = "The identifier of the GCS bucket to create."
  type        = string
}
variable "alta_user" {
  description = "The user that the Alta tool runs as."
  type        = string
  default     = "serviceAccount:verily-sensors-batch-jobs@system.gserviceaccount.com"
}
