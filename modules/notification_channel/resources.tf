resource "google_monitoring_notification_channel" {
  count        = var.type == "email" ? 1 : 0

  project = var.project_id
  display_name = var.display_name
  type         = "email"

  labels = {
    email_address = var.email_address
  }
}
