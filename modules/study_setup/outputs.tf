output "project_bindings" {
  value = local.project_bindings
  description = "Automated project bindings for the SensorSuite study project."
}

output "logging_sink_email" {
  value = google_logging_project_sink.logging_sink.writer_identity
  description = "The service account email for the logging sink."
}
