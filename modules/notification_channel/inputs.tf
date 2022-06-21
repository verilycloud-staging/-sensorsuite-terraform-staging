variable "project_id" {
  description = "The GCP project ID to create the channel in."
  type        = string
}

variable "type" {
  description = "Type of the notification channel."
  type        = string
  validation {
    condition = var.type == "email"
    error_message = "Only `email` is supported."
  }
}

variable "display_name" {
  description = "Display name of the notification channel."
  type        = string
  default = ""
}

variable "email_address" {
  description = "Email address to send notifications to."
  type        = string
}
