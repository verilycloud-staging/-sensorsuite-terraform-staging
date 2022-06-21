terraform {
  required_providers {
    # Note that google_api_gateway* is only supported by google-beta (as of
    #/ 2022/02/10).
    google-beta = ">= 3.48.0"
  }
}

resource "google_project_service" "apigateway" {
  project = var.project_id
  service = "apigateway.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "servicemanagement" {
  project = var.project_id
  service = "servicemanagement.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "servicecontrol" {
  project = var.project_id
  service = "servicecontrol.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy = false
}

# Service account to run the API Gateways as.
resource "google_service_account" "default" {
  project      = var.project_id
  account_id   = "${var.api_id}-apig"
  display_name = "API Gateway Service Account - ${var.api_id}"
  description  = "API Gateway Identity"
}

# Give the `ci_service_account` ability to impersonate the gateway user for
# deployments.
data "google_iam_policy" "gwsa" {
  binding {
    role = "roles/iam.serviceAccountUser"
    members = var.ci_service_account == "" ? [] : ["serviceAccount:${var.ci_service_account}"]
  }
}
resource "google_service_account_iam_policy" "default" {
  service_account_id = google_service_account.default.name
  policy_data        = data.google_iam_policy.gwsa.policy_data
}

resource "google_api_gateway_api" "default" {
  provider     = google-beta
  api_id       = var.api_id
  display_name = var.display_name
  project      = var.project_id
  depends_on = [
    google_project_service.apigateway,
    google_project_service.servicemanagement,
    google_project_service.servicecontrol,
  ]
}

resource "google_api_gateway_api_iam_binding" "admins" {
  provider = google-beta
  project  = var.project_id
  api      = google_api_gateway_api.default.api_id
  role     = "roles/apigateway.admin"
  members  = var.ci_service_account == "" ? [] : ["serviceAccount:${var.ci_service_account}"]
}
# Setting the CISA as an apigateway.admin on the API resource (above) isn't
# enough to manage API configurations. The account also needs API Gateway viewer
# permissions at the project level (to check LRO statuses). See the note at
# https://cloud.google.com/api-gateway/docs/api-access-overview which alludes to
# this (even if poorly worded).
resource "google_project_iam_member" "project_viewer" {
  count = var.ci_service_account == "" ? 0 : 1
  project = var.project_id
  role = "roles/apigateway.viewer"
  member = "serviceAccount:${var.ci_service_account}"
  # Needs to be unconditional to check project-wide operation resources.
}
# Also as part of the workaround, the CISA needs admin privileges to create
# configs at the project level, but IAM conditions can be used to scope
# access to this API Gateway only.
resource "google_project_iam_member" "conditional_project_admin" {
  count = var.ci_service_account == "" ? 0 : 1
  project = var.project_id
  role = "roles/apigateway.admin"
  member = "serviceAccount:${var.ci_service_account}"
  condition {
    title = "Only on ${google_api_gateway_api.default.api_id}"
    expression = "resource.name.startsWith(\"${google_api_gateway_api.default.id}/configs/\")"
  }
}

resource "google_endpoints_service_iam_binding" "consumers" {
  service_name = google_api_gateway_api.default.managed_service
  role = "roles/servicemanagement.serviceConsumer"
  members = var.service_consumers
}

resource "google_api_gateway_api_config" "default" {
  provider = google-beta
  project = var.project_id
  api = google_api_gateway_api.default.api_id
  display_name = "Initial config. Do not use after you've deployed an API Gateway Plato service."
  gateway_config {
    backend_config {
      google_service_account = google_service_account.default.email
    }
  }
  openapi_documents {
    document {
      path     = "initial.yaml"
      contents = filebase64("${path.module}/initial.yaml")
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "default" {
  for_each = toset(var.regions)

  provider   = google-beta
  project    = var.project_id
  api_config = google_api_gateway_api_config.default.id
  gateway_id = var.api_id
  region     = each.key

  lifecycle {
    ignore_changes = [
      api_config,
    ]
  }
}

resource "google_api_gateway_gateway_iam_binding" "default" {
  for_each = toset(var.regions)

  provider = google-beta
  project  = var.project_id
  gateway  = google_api_gateway_gateway.default[each.key].gateway_id
  region   = each.key
  role = "roles/apigateway.admin"
  members = var.ci_service_account == "" ? [] : ["serviceAccount:${var.ci_service_account}"]
}
