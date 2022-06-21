locals {
  location_to_region = tomap({
    "US" = "us-central1",
    "EU" = "europe-west1",
  })
  all_locations = toset([for p in var.individual_pipeline_parameters : p.location])
  admin_project = replace(var.project_id, var.environment, "admin")

  # indexes the input list using a map
  config_indexes_map = { for i, config in var.individual_pipeline_parameters : tostring(i) => config }
  # creates a list of indexes for batch configs
  batch_indexes = compact([for i, config in local.config_indexes_map : config.is_streaming ? "" : i])
  # creates a list of indexes for streaming configs
  streaming_indexes = compact([for i, config in local.config_indexes_map : config.is_streaming ? i : ""])
  # Filters the configs list to only include configs for batch pipelines
  batch_configs = [for index in local.batch_indexes : lookup(local.config_indexes_map, index)]
  # Filters the configs list to only include configs for streaming pipelines
  streaming_configs = [for index in local.streaming_indexes : lookup(local.config_indexes_map, index)]
}

// Creates the service account for the pipeline
resource "google_service_account" "pipeline_service_account" {
  account_id = var.service_name
  project    = var.project_id
}
# Grants the service account worker access to start BigQuery jobs
resource "google_project_iam_member" "bq_admin_role" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}
# Grants the service account worker access to dataflow
resource "google_project_iam_member" "dataflow_admin_role" {
  project = var.project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}
# Grants the service account admin access to dataflow
resource "google_project_iam_member" "dataflow_worker_role" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}
# Grants the service account "service account user". Flex template launches use
# a different service account.
resource "google_project_iam_member" "service_account_user_role" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}
# Grants the service account service usage consumer for reading from BigQuery.
resource "google_project_iam_member" "service_usage_consumer_role" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}
# Grants the service account serviceAccountTokenCreator for impersonated creds.
resource "google_project_iam_member" "service_account_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

# Grants the service account storage read access on the admin project for
# pulling the docker images (flex template images).
resource "google_project_iam_member" "storage_viewer_role" {
  project = local.admin_project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

// Creates the GCS bucket for Dataflow temp files
resource "google_storage_bucket" "dataflow_temp_bucket" {
  for_each                    = local.all_locations
  name                        = "${var.service_name}-${var.environment}-${lower(each.key)}-temp"
  location                    = each.key
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = true
  lifecycle_rule {
    condition {
      age = 14
    }
    action {
      type = "Delete"
    }
  }
}
// Creates the staging directory
resource "google_storage_bucket_object" "staging_folder" {
  for_each = local.all_locations
  name     = "staging/"
  content  = "Directory for storing Dataflow staging files."
  bucket   = google_storage_bucket.dataflow_temp_bucket[each.key].name
}
// Creates the temp directory
resource "google_storage_bucket_object" "temp_folder" {
  for_each = local.all_locations
  name    = "temp/"
  content = "Directory for storing Dataflow temp files."
  bucket  = google_storage_bucket.dataflow_temp_bucket[each.key].name
}
# Grants the service account access to the gcs bucket
resource "google_project_iam_member" "storage_admin_role" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

# Creates the pubsub topics for Streaming pipelines
resource "google_pubsub_topic" "upload_notifications" {
  for_each = { for c in local.streaming_configs : c.registry => c }
  project  = var.project_id
  name     = format("ds-sdk-upload-notifications-topic-%s-%s", replace(lower(each.key), "_", "-"), lower(var.service_name))
}
# Creates the pubsub subscriptions for Streaming pipelines
resource "google_pubsub_subscription" "upload_notifications" {
  for_each = { for c in local.streaming_configs : c.registry => c }
  project  = var.project_id
  topic    = google_pubsub_topic.upload_notifications[each.key].name
  name     = format("ds-sdk-upload-notifications-subscription-%s-%s", replace(lower(each.key), "_", "-"), lower(var.service_name))
}
# Grants project-level pubsub permissions to the service account.
resource "google_project_iam_member" "pubsub_subscriber_role" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}
resource "google_project_iam_member" "pubsub_viewer_role" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}
# Grants the SensorStore service account permission to add to the topic
resource "google_pubsub_topic_iam_member" "pubsub_publisher_role" {
  for_each = { for c in local.streaming_configs : c.registry => c }
  project  = var.project_id
  topic    = google_pubsub_topic.upload_notifications[each.key].name
  role     = "roles/pubsub.publisher"
  member   = "serviceAccount:lifescience-sensors-store@system.gserviceaccount.com"
}
# Creates redis instances for streaming pipelines.
resource "google_redis_instance" "redis_data_source_cache" {
  for_each       = { for c in local.streaming_configs : c.registry => c }
  project        = var.project_id
  name           = format("cache-%s-%s", substr(replace(lower(each.key), "_", "-"), 0, 18), substr(lower(var.service_name), 0, 10))
  tier           = "BASIC"
  region         = local.location_to_region[each.value.location]
  memory_size_gb = 1
}
# Grants the service account access to edit Redis contents
resource "google_project_iam_member" "redis_editor_role" {
  project = var.project_id
  role    = "roles/redis.editor"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

// Creates the Cloud Scheduler job for each Batch pipeline
resource "google_cloud_scheduler_job" "batch_launcher" {

  # We need to convert the map to be able to for_each loop over the registries.
  # {registry_name: {registry: registry_name, additional_params: {...}}}
  for_each = { for c in local.batch_configs : c.registry => c }

  name      = "batch-${var.service_name}-${each.key}-launcher"
  project   = var.project_id
  schedule  = each.value.cloud_scheduler_options.schedule
  time_zone = each.value.cloud_scheduler_options.time_zone
  region    = local.location_to_region[each.value.location]

  http_target {
    http_method = "POST"
    uri         = "https://dataflow.googleapis.com/v1b3/projects/${var.project_id}/locations/${local.location_to_region[each.value.location]}/flexTemplates:launch"
    headers = {
      "Content-Type" = "application/json"
    }
    oauth_token {
      service_account_email = google_service_account.pipeline_service_account.email
    }
    # HTTP command for launching the batch job from the flex template.
    # containerSpecGcsPath is defined in the ds-sdk-pipeline service template.
    body = base64encode(<<-EOT
    {
      "launchParameter": {
        "jobName": "${replace(format("%s-%s-batch", lower(var.service_name), lower(each.key)), "_", "-")}",
        "parameters": {
          "is_streaming": "False",
          "registry": "${each.key}",
          "service_account_email" : "${google_service_account.pipeline_service_account.email}",
          "temp_gcs_bucket" : "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.temp_folder[each.value.location].name}",
          "runner": "Dataflow",
          ${join(",\n      ", [for key, value in each.value.additional_params : "\"${key}\": \"${value}\""])}
        },
        "environment": {
          "tempLocation": "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.temp_folder[each.value.location].name}",
          "stagingLocation": "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.staging_folder[each.value.location].name}",
          "workerZone": "${local.location_to_region[each.value.location]}-b",
          "additionalExperiments": [
            "enable_stackdriver_agent_metrics",
            "min_num_workers=${each.value.dataflow_options.min_num_workers}",
            "prebuild_sdk_container_engine=cloud_build"
          ],
          "machineType": "${each.value.dataflow_options.machine_type}",
        },
        "containerSpec": {
          "image": "gcr.io/${local.admin_project}/services/${var.service_name}:${var.environment}",
          "defaultEnvironment": {},
          "sdkInfo": {
            "language": "PYTHON"
          },
          "metadata": {
            "name": "${var.service_name} dataflow flex template",
            "parameters": [
              {
                "name": "is_streaming"
              },
              {
                "name": "registry"
              },
              {
                "name": "service_account_email"
              },
              {
                "name": "temp_gcs_bucket"
              },
              {
                "name": "runner"
              },
              ${join(",\n          ", [for key in keys(each.value.additional_params) : "{\n           \"name\": \"${key}\"\n          }"])}
            ]
          }
        },
      }
    }
EOT
    )
  }
}
// Creates the Cloud Scheduler job for updating each Streaming pipeline
resource "google_cloud_scheduler_job" "streaming_updater" {

  # We need to convert the map to be able to for_each loop over the registries.
  # {registry_name: {registry: registry_name, additional_params: {...}}}
  for_each = { for p in local.streaming_configs : p.registry => p }

  name      = "streaming-${var.service_name}-${each.key}-updater"
  project   = var.project_id
  schedule  = each.value.cloud_scheduler_options.schedule
  time_zone = each.value.cloud_scheduler_options.time_zone
  region    = local.location_to_region[each.value.location]

  http_target {
    http_method = "POST"
    uri         = "https://dataflow.googleapis.com/v1b3/projects/${var.project_id}/locations/${local.location_to_region[each.value.location]}/flexTemplates:launch"
    headers = {
      "Content-Type" = "application/json"
    }
    oauth_token {
      service_account_email = google_service_account.pipeline_service_account.email
    }
    # HTTP command for launching the streaming job from the flex template.
    # containerSpecGcsPath is defined in the ds-sdk-pipeline service template.
    body = base64encode(<<-EOT
    {
      "launchParameter": {
        "jobName": "${replace(format("%s-%s-streaming", lower(var.service_name), lower(each.key)), "_", "-")}",
        "update": true,
        "parameters": {
          "is_streaming": "True",
          "redis_endpoint": "${google_redis_instance.redis_data_source_cache[each.key].host}:${google_redis_instance.redis_data_source_cache[each.key].port}",
          "pub_sub_subscriber": "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.upload_notifications[each.key].name}",
          "registry": "${each.key}",
          "service_account_email" : "${google_service_account.pipeline_service_account.email}",
          "temp_gcs_bucket" : "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.temp_folder[each.value.location].name}",
          "runner": "Dataflow",
          ${join(",\n      ", [for key, value in each.value.additional_params : "\"${key}\": \"${value}\""])}
        },
        "environment": {
          "tempLocation": "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.temp_folder[each.value.location].name}",
          "stagingLocation": "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.staging_folder[each.value.location].name}",
          "workerZone": "${local.location_to_region[each.value.location]}-b",
          "additionalExperiments": [
            "enable_stackdriver_agent_metrics",
            "min_num_workers=${each.value.dataflow_options.min_num_workers}",
            "prebuild_sdk_container_engine=cloud_build"
          ],
          "machineType": "${each.value.dataflow_options.machine_type}",
        },
        "containerSpec": {
          "image": "gcr.io/${local.admin_project}/services/${var.service_name}:${var.environment}",
          "defaultEnvironment": {},
          "sdkInfo": {
            "language": "PYTHON"
          },
          "metadata": {
            "name": "${var.service_name} dataflow flex template",
            "parameters": [
              {
                "name": "is_streaming"
              },
              {
                "name": "redis_endpoint"
              },
              {
                "name": "pub_sub_subscriber"
              },
              {
                "name": "registry"
              },
              {
                "name": "service_account_email"
              },
              {
                "name": "temp_gcs_bucket"
              },
              {
                "name": "runner"
              },
              ${join(",\n          ", [for key in keys(each.value.additional_params) : "{\n           \"name\": \"${key}\"\n          }"])}
            ]
          }
        },
      }
    }
EOT
    )
  }
}
// Creates the Cloud Scheduler job for launching each Streaming pipeline
resource "google_cloud_scheduler_job" "streaming_launcher" {

  # We need to convert the map to be able to for_each loop over the registries.
  # {registry_name: {registry: registry_name, additional_params: {...}}}
  for_each = { for p in local.streaming_configs : p.registry => p }

  name    = "streaming-${var.service_name}-${each.key}-launcher"
  project = var.project_id
  # Runs every leap year that falls on a monday. Closest thing I could find to
  # not running at all; This command is just for manually launching a streaming
  # pipeline (the command above will update it on the given schedule).
  schedule  = "0 0 29 2 1"
  time_zone = each.value.cloud_scheduler_options.time_zone
  region    = local.location_to_region[each.value.location]

  http_target {
    http_method = "POST"
    uri         = "https://dataflow.googleapis.com/v1b3/projects/${var.project_id}/locations/${local.location_to_region[each.value.location]}/flexTemplates:launch"
    headers = {
      "Content-Type" = "application/json"
    }
    oauth_token {
      service_account_email = google_service_account.pipeline_service_account.email
    }
    # HTTP command for launching the streaming job from the flex template.
    # containerSpecGcsPath is defined in the ds-sdk-pipeline service template.
    body = base64encode(<<-EOT
    {
      "launchParameter": {
        "jobName": "${replace(format("%s-%s-streaming", lower(var.service_name), lower(each.key)), "_", "-")}",
        "update": false,
        "parameters": {
          "is_streaming": "True",
          "redis_endpoint": "${google_redis_instance.redis_data_source_cache[each.key].host}:${google_redis_instance.redis_data_source_cache[each.key].port}",
          "pub_sub_subscriber": "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.upload_notifications[each.key].name}",
          "registry": "${each.key}",
          "service_account_email" : "${google_service_account.pipeline_service_account.email}",
          "temp_gcs_bucket" : "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.temp_folder[each.value.location].name}",
          "runner": "Dataflow",
          ${join(",\n      ", [for key, value in each.value.additional_params : "\"${key}\": \"${value}\""])}
        },
        "environment": {
          "tempLocation": "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.temp_folder[each.value.location].name}",
          "stagingLocation": "gs://${google_storage_bucket.dataflow_temp_bucket[each.value.location].name}/${google_storage_bucket_object.staging_folder[each.value.location].name}",
          "workerZone": "${local.location_to_region[each.value.location]}-b",
          "additionalExperiments": [
            "enable_stackdriver_agent_metrics",
            "min_num_workers=${each.value.dataflow_options.min_num_workers}",
            "prebuild_sdk_container_engine=cloud_build"
          ],
          "machineType": "${each.value.dataflow_options.machine_type}",
        },
        "containerSpec": {
          "image": "gcr.io/${local.admin_project}/services/${var.service_name}:${var.environment}",
          "defaultEnvironment": {},
          "sdkInfo": {
            "language": "PYTHON"
          },
          "metadata": {
            "name": "${var.service_name} dataflow flex template",
            "parameters": [
              {
                "name": "is_streaming"
              },
              {
                "name": "redis_endpoint"
              },
              {
                "name": "pub_sub_subscriber"
              },
              {
                "name": "registry"
              },
              {
                "name": "service_account_email"
              },
              {
                "name": "temp_gcs_bucket"
              },
              {
                "name": "runner"
              },
              ${join(",\n          ", [for key in keys(each.value.additional_params) : "{\n           \"name\": \"${key}\"\n          }"])}
            ]
          }
        },
      }
    }
EOT
    )
  }
}
# Grants the service account access to Cloud Scheduler
resource "google_project_iam_member" "cloud_scheduler_admin_role" {
  project = var.project_id
  role    = "roles/cloudscheduler.admin"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

# Grants the service account access to write memory metrics
resource "google_project_iam_member" "metric_writer_role" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.pipeline_service_account.email}"
}

# Creates the notification channel for alerts that are triggered
resource "google_monitoring_notification_channel" "email" {
  display_name = "Alerting Email: ${var.alert_email}, ${var.service_name}"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
  project = var.project_id
}

// Creates the alerting policy for Dataflow jobs
resource "google_monitoring_alert_policy" "dataflow_alert_policy" {
  display_name = "Dataflow Job Alerting Policy: ${var.service_name}"
  project      = var.project_id
  combiner     = "OR"
  notification_channels = [
    "${google_monitoring_notification_channel.email.name}",
  ]
  documentation {
    mime_type = "text/markdown"
    content   = "See go/ds-sdk-scheduler-playbook for more information."
  }
  conditions {
    display_name = "pipeline failure"
    condition_monitoring_query_language {
      query    = "fetch dataflow_job | metric 'dataflow.googleapis.com/job/is_failed' | filter (resource.job_name =~ '.*${var.service_name}.*') | group_by 5m, [value_is_failed_sum: sum(value.is_failed)] | every 5m | condition val() > 0 '1'"
      duration = "0s"
    }
  }
}
