variable "project_id" {
  description = "The GCP project ID to add alerts to."
  type        = string
}

variable "pipeline_name" {
  description = "The name of the pipeline to create alerts for."
  type        = string
}

variable "alert_email" {
  description = "The email that alert notifications should be sent to."
  type        = string
}

variable "playbook_url" {
  description = "Link to the playbook for the alert."
  type = string
}


