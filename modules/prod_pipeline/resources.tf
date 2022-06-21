// The below terraform assumes a project (var.project_id) has already been created.
// To create a project see: go/verily-kumo-create
// TODO(b/170419839): These projects should be created via VerilyCloud once that is available.

// Set up service account.
module "pipeline_service_account" {
  source = "../../kumo/v5/service_account"
  account_name = var.pipeline_service_account_name
  project_id = var.project_id
  additional_bindings = [{
    role = "roles/iam.serviceAccountTokenCreator"
    members = ["serviceAccount:${var.pipeline_service_account_name}@${var.project_id}.iam.gserviceaccount.com"]
  }]
}

// Enable APIs
resource "google_project_service" "sensor_store_api" {
  project = var.project_id
  service = "lifesciencesensorstore.googleapis.com"
}

resource "google_project_service" "iam_credentials_api" {
  project = var.project_id
  service = "iamcredentials.googleapis.com"
}

resource "google_project_service" "dataflow_api" {
  project = var.project_id
  service = "dataflow.googleapis.com"
}

resource "google_project_service" "pubsub_api" {
  project = var.project_id
  service = "pubsub.googleapis.com"
}

// Set up Secret Manager with API key (API key is passed in as a parameter)
module "api_key_secret" {
  source = "../../kumo/v5/secret_manager/secret_manager_secret"

  project_id = var.project_id
  secret_id = "ds-sdk-api-key"
  additional_bindings = [{
    role = "roles/secretmanager.secretAccessor"
    members = ["serviceAccount:${module.pipeline_service_account.email}"]
  }]
}

// Set up GCS Bucket for cloud dataflow jobs.
module "cloud_dataflow_bucket" {
  source = "../../kumo/v5/bucket"

  project_id = var.project_id
  bucket_name = var.cloud_dataflow_bucket_name
  additional_bindings = [{
    role = "roles/storage.objectAdmin"
    members = ["serviceAccount:${module.pipeline_service_account.email}"]
  }]
}

// Set up Pub/Sub subscriber
module "pubsub_subscriber" {
  source = "../../kumo/v5/pubsub/pubsub_subscriptions"

  project_id = var.project_id
  topic = var.sensor_store_pubsub_topic
  subscriptions = [{"name" = var.pubsub_subscription_name}] 
}

resource "google_pubsub_subscription_iam_member" "subscriber" {
  project = var.project_id
  subscription = module.pubsub_subscriber.subscription_paths[0]
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${module.pipeline_service_account.email}"
}
