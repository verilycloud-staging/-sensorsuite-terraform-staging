variable "environment" {
  description = "The Plato environment."
  type        = string
}

variable "project_id" {
  description = "The GCP project ID to configure."
  type        = string
}

variable "service_name" {
  description = "The name of the DS SDK pipeline service (declared in the DS SDK pipeline template)"
  type        = string
}

variable "individual_pipeline_parameters" {
  type = list(object({
    registry          = string
    location          = string
    is_streaming      = bool
    additional_params = map(string)
    cloud_scheduler_options = object({
      schedule  = string
      time_zone = string
    })
    dataflow_options = object({
      machine_type  = string
      min_num_workers = string
    })
  }))
  default = [
    {
      "registry"     = "DevTeam_Autopush"
      "location"     = "US"
      "is_streaming" = true
      "additional_params" = {
        "sensor_store_env" = "autopush"
      }
      "cloud_scheduler_options" = {
        "schedule"  = "0 1 * * *"
        "time_zone" = "Etc/UTC"
      }
      "dataflow_options" = {
        "machine_type"  = "n2-standard-4"
        "min_num_workers" = "1"
      }
    },
    {
      "registry"     = "WDP"
      "location"     = "US"
      "is_streaming" = false
      "additional_params" = {
        "sensor_store_env" = "prod"
      }
      "cloud_scheduler_options" = {
        "schedule"  = "0 1 * * *"
        "time_zone" = "Etc/UTC"
      }
      "dataflow_options" = {
        "machine_type"  = "n2-standard-4"
        "min_num_workers" = "1"
      }
    },
  ]
}

variable "alert_email" {
  description = "The email to send job alerts to."
  type        = string
}
