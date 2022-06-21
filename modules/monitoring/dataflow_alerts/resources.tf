module "incompatible_update_alert" {
  source = "./incompatible_update"
  project_id = var.project_id
  pipeline_name = var.pipeline_name
  alert_email = var.alert_email
  playbook_url = var.incompatible_update_playbook_url
}

module "latency_alert" {
  source = "./latency"
  project_id = var.project_id
  pipeline_name = var.pipeline_name
  alert_email = var.alert_email
  playbook_url = var.latency_playbook_url
}

module "worker_error_log_alert" {
  source = "./worker_error_log"
  project_id = var.project_id
  pipeline_name = var.pipeline_name
  alert_email = var.alert_email
  playbook_url = var.worker_error_log_playbook_url
  alert_threshold = var.worker_error_log_alert_threshod
}

