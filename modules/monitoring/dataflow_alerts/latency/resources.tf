resource "google_monitoring_notification_channel" "email_notification" {
  project=var.project_id
  display_name = var.alert_email
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "latency_alert" {
  project=var.project_id
  display_name = "Latency alert ${var.pipeline_name}"
  documentation {
    content = "PLAYBOOK: ${var.playbook_url}"
  }
  notification_channels = [ google_monitoring_notification_channel.email_notification.name ]
  combiner = "OR"
  conditions {
    display_name = "worker error log condition"
    condition_monitoring_query_language {
      query = <<EOF
fetch dataflow_job
| { t_0:
      metric 'dataflow.googleapis.com/job/user_counter'
      | filter
          (metric.metric_name =~ '.*960000.*'
           && metric.ptransform =~ '.*Step.*'
           && resource.job_name = '${var.pipeline_name}')
      | group_by 1m, [value_user_counter_mean: mean(value.user_counter)]
      | every 1m
      | group_by [],
          [value_user_counter_mean_aggregate:
             aggregate(value_user_counter_mean)]
      | align rate(1m)
  ; t_1:
      metric 'dataflow.googleapis.com/job/user_counter'
      | filter
          (metric.ptransform =~ '.*Step.*'
           && resource.job_name = '${var.pipeline_name}')
      | group_by 1m, [value_user_counter_mean: mean(value.user_counter)]
      | every 1m
      | group_by [],
          [value_user_counter_mean_aggregate:
             aggregate(value_user_counter_mean)]
      | align rate(1m) }
| ratio
| condition ratio > .1 '1'
EOF
      # 900 seconds
      duration = "900s"
    }
  }
}
