resource "google_logging_metric" "incompatible_update_log" {
  name = "incompatible_update_log/${var.pipeline_name}"
  project = var.project_id
  filter = join(" AND ", [
    "resource.type=\"dataflow_step\"",
    "labels.\"dataflow.googleapis.com/job_name\"=\"${var.pipeline_name}\"",
    "severity>=ERROR",
    "\"The new job is not compatible\""
  ])
  metric_descriptor {
    metric_kind = "DELTA"
    value_type = "INT64"
  }
}

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
  display_name = "Incompatible update alert for ${var.pipeline_name}"
  documentation {
    content = "PLAYBOOK: ${var.playbook_url}"
  }
  notification_channels = [ google_monitoring_notification_channel.email_notification.name ]
  combiner = "OR"
  conditions {
    display_name = "worker error log condition"
    condition_threshold {
      threshold_value = 0
      filter = join(" AND ", [
          "metric.type=\"logging.googleapis.com/user/${google_logging_metric.incompatible_update_log.name}\"",
          "resource.type=\"dataflow_job\"",
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

