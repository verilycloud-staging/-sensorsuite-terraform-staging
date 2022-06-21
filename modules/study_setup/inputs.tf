variable "project_id" {
  description = "The GCP project ID to configure."
  type        = string
}

variable "data_readers_two_sync_group_name" {
  description = "The name of the two sync group to grant access. NOTE: @twosync.google.com should not be included"
  type        = string
}

variable "ds_sdk_service_account_name" {
  description = "The name of the service account to be created for running DS SDK pipelines."
  type        = string
  default     = "ds-sdk-readers"
}

variable "location" {
  description = "The location to create resources in (applices to BigQuery datasets and GCS buckets)."
  type        = string
  default     = "US"
}

variable "bucket_storage_class" {
  description = "The storage class to use when creating GCS buckets"
  type        = string
  default     = "STANDARD"
}
