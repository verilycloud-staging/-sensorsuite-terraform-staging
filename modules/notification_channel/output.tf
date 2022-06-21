output "channel_name" {
  value       = resource.google_monitoring_notification_channel.default.name
  description = "ID of the notification channel. For use in alert policies."
}
