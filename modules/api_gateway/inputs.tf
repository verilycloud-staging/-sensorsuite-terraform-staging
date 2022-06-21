variable "project_id" {
  description = "The GCP project ID to configure."
  type        = string
}

variable "api_id" {
  description = "ID of the API. Must be unique within the project."
  type        = string
}

variable "display_name" {
  description = "Display name of the API."
  type        = string
  default     = ""
}

variable "regions" {
  description = "Regions to deploy the API Gateway in."
  type        = list(string)
}

variable "ci_service_account" {
  description = "Email address of the workflow service account that should be allowed to deploy configs for this API. eg. The GCP service account running a GitHub Action."
  type = string
  default = ""
}

variable "service_consumers" {
  description = "IAM entities allowed to consume this API. Granted roles/servicemanagement.serviceConsumer"
  type = list(string)
  default = []
}
