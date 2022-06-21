resource "google_monitoring_notification_channel" "email_notification" {
  project=var.project_id
  display_name = var.alert_email
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "worker_error_log_alert" {
  project=var.project_id
  display_name = "Worker error log alert for ${var.pipeline_name}"
  documentation {
    content = "PLAYBOOK: ${var.playbook_url}"
  }
  notification_channels = [ google_monitoring_notification_channel.email_notification.name ]
  combiner = "OR"
  conditions {
    display_name = "worker error log condition"
    condition_threshold {
      threshold_value = var.alert_threshold
      filter = join(" AND ", [
          "metric.type=\"logging.googleapis.com/log_entry_count\"",
          "resource.type=\"dataflow_job\"",
          "metric.label.severity=\"ERROR\"",
          "resource.label.job_name=\"${var.pipeline_name}\"",
          "resource.label.project_id=\"${var.project_id}\"",
          "metric.label.log=\"dataflow.googleapis.com/worker\""
      ])
      aggregations {
        alignment_period = "300s"
        per_series_aligner = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
      duration = "60s"
      comparison = "COMPARISON_GT"
    }
  }
}
