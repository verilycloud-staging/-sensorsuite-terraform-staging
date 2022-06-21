variable "project_id" {
  description = "The GCP project ID to configure."
  type        = string
}

variable "pipeline_service_account_name" {
  description = "The name of the service account to be created for running the pipeline."
  type        = string
}

variable "cloud_dataflow_bucket_name" {
  description = "The name of the GCS bucket to use for Cloud Dataflow."
  type        = string
}

variable "sensor_store_pubsub_topic" {
  description = "The SensorStore pubsub topic to create a subscriber for."
  type        = string
}

variable "pubsub_subscription_name" {
  description = "The name of the Subscriber to create that is subscribed to var.sensor_store_pubsub_topic"
  type        = string
}
