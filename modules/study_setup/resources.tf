locals {

  data_readers_two_sync_group_role = "group:${var.data_readers_two_sync_group_name}@twosync.google.com"
  data_readers_mdb_group_role = "mdb:${var.data_readers_two_sync_group_name}"
  ds_sdk_service_account_role = format("serviceAccount:%s@%s.iam.gserviceaccount.com", var.ds_sdk_service_account_name, var.project_id)
  vsbj_service_account = "serviceAccount:verily-sensors-batch-jobs@system.gserviceaccount.com"
  gcp_service_account_streaming = "serviceAccount:verily-sensors-gcp@sensorsuite-pipelines.iam.gserviceaccount.com"
  gcp_service_account_batch = "serviceAccount:verily-sensors-gcp@sensorsuite-pipelines-batch.iam.gserviceaccount.com"
  sensorsuite_service_account = "serviceAccount:lifescience-sensors-store@system.gserviceaccount.com"

  # Project IAM bindings to apply to the Verily Plato project.
  project_bindings = [
      {
        role = "roles/bigquery.user"
        members = [local.ds_sdk_service_account_role]
      },
      {
        role = "roles/bigquery.jobUser"
        members = [local.data_readers_two_sync_group_role]
      },
      {
        role = "roles/bigquery.dataViewer"
        members = [
          local.data_readers_two_sync_group_role,
          local.ds_sdk_service_account_role
        ]
      },
      {
        role = "roles/storage.objectViewer",
        members = [
          local.data_readers_two_sync_group_role,
          local.data_readers_mdb_group_role
        ]
      },
      {
        role = "roles/pubsub.editor",
        members = [
          # Allows streaming dataflow jobs to create a temporary subscription
          local.ds_sdk_service_account_role
        ]
      },
      {
        role = "roles/serviceusage.serviceUsageConsumer"
        # Allows service account to bill API usage to the project.
        members = [local.ds_sdk_service_account_role]
      },
      {
        role = "roles/viewer",
        members = [local.data_readers_two_sync_group_role]
      },
      {
        role = "roles/bigquery.admin"
        members = [
          local.vsbj_service_account,
          local.gcp_service_account_streaming,
          local.gcp_service_account_batch,
          # Service account for launching step count pipelines.
          "serviceAccount:step-count-streaming-pip-ci-sa@sensorsuite-eqkj-admin.iam.gserviceaccount.com",
          # This service account is used for metrics jobs.
          "serviceAccount:verily-sensors-data-export@system.gserviceaccount.com",
          "group:sensorsuite-breakglass@verilygroups.com",
        ]
      },
      {
        role = "roles/bigquery.metadataViewer"
        members = [local.sensorsuite_service_account]
      },
      {
        role = "roles/storage.admin"
        members = [
          local.vsbj_service_account,
          local.sensorsuite_service_account,
        ]
      },
      {
        role = "roles/dataflow.developer"
        members = [local.data_readers_two_sync_group_role]
      },
      {
        role = "roles/dataflow.worker"
        members = [local.ds_sdk_service_account_role]
      },
      {
        role = "roles/secretmanager.admin"
        members = [
          "group:sensorsuite-breakglass@verilygroups.com",
          "group:verily-sensors-oncall@twosync.google.com",
        ]
      },
      {
        role = "roles/bigquery.readSessionUser"
        members = [
          local.data_readers_two_sync_group_role,
          local.ds_sdk_service_account_role
        ]
      }
    ]

  # make a map from a role to a flattened list of distinct members.
  project_bindings_map = {
    for role, member_lists in {
      for binding in local.project_bindings:
      binding.role => binding.members...
    }:
    role => distinct(flatten(member_lists))
  }
  # distill the map from above to a list of objects for a single binding
  member_project_bindings = flatten([
    for role, members in local.project_bindings_map: [
      for member in members:
      {
        role = role
        member = member
      }
    ]
  ])

}

module "ds_sdk_service_account" {
  source = "../../../kumo-terraform-modules/v10/service_account"
  account_name = var.ds_sdk_service_account_name
  project_id = var.project_id
  account_description = "Service account used to run DS SDK pipelines."
  service_account_token_creators = [
      # Allow service account to create tokens for itself, this allows us to
      # fetch short term credentials with different scopes.
      "serviceAccount:${var.ds_sdk_service_account_name}@${var.project_id}.iam.gserviceaccount.com",
      # Allow MDB group to use service account, this allows members of the group
      # to launch flume jobs that can auth as this service account.
      local.data_readers_mdb_group_role
  ]
  service_account_users = [
    local.data_readers_two_sync_group_role
  ]
}

module "ds_sdk_bigquery_dataset" {
  source = "../../../kumo-terraform-modules/v10/bigquery_dataset"
  project_id = var.project_id
  name = "datascience_sdk_temp"
  location = var.location
  default_table_expiration_hr = 72
  bigquery_data_owners = [
    local.data_readers_two_sync_group_role
  ]
  bigquery_data_editors = [
    local.ds_sdk_service_account_role
  ]
}

module "ds_sdk_temp_bucket" {
  source = "../../../kumo-terraform-modules/v10/bucket"
  project_id = var.project_id
  bucket_name = "${var.project_id}-ds-sdk-temp"
  location = var.location
  storage_class = var.bucket_storage_class
  storage_object_admins = [
    local.ds_sdk_service_account_role,
    local.data_readers_two_sync_group_role,
    local.vsbj_service_account
  ]
  lifecycle_rules = [
    {
      age = 2
      action_type = "Delete"
    }
  ]
}

module "echo_temp_bucket" {
  source = "../../../kumo-terraform-modules/v10/bucket"
  project_id = var.project_id
  bucket_name = "${var.project_id}-echo-loader"
  location = var.location
  storage_class = var.bucket_storage_class
  storage_object_admins = [
    local.vsbj_service_account
  ]
  lifecycle_rules = [
    {
      age = 14
      action_type = "Delete"
    }
  ]
}

resource "google_project_iam_member" "project_bindings" {
  # use "role  member" as a key for the iam_member resources
  for_each = {
    for binding in local.member_project_bindings:
    format("%s  %s", binding.role, binding.member) => binding
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [
    module.ds_sdk_service_account,
  ]
}

resource "google_logging_project_sink" "logging_sink" {
  name = format("%s_logs_to_bq", replace(var.project_id, "-", "_"))
  project = var.project_id
  destination = "bigquery.googleapis.com/projects/sensorsuite-audit-log/datasets/audit_logs"
  filter = ""
  # Use a unique writer (creates a unique service account used for writing)
  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }
}
