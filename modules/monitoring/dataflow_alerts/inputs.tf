variable "project_id" {
  description = "The GCP project ID to add alerts to."
  type        = string
}

variable "pipeline_name" {
  description = "The name of the pipeline to create alerts for."
  type        = string
}

variable "worker_error_log_alert_threshod" {
  description = "The number of error logs to alert on. Alert will be trigger when number of worker logs per minute > alert_threshold"
  type        = number
  default     = 0
}

variable "alert_email" {
  description = "The email that alert notifications should be sent to."
  type        = string
}

variable "incompatible_update_playbook_url" {
  description = "Link to the playbook for incompatible pipieline update alert."
  type = string
}

variable "worker_error_log_playbook_url" {
  description = "Link to the playbook for worker error log alert."
  type = string
}

variable "latency_playbook_url" {
  description = "Link to the playbook for latency alert."
  type = string
}


