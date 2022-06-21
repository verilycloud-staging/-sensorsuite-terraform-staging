output "gateway_identity" {
  value       = "serviceAccount:${resource.google_service_account.default.email}"
  description = "Email address of the API gateway identity prefixed with 'serviceAccount:'. Intended for use in other Plato resource parameters."
}

output "gateway_identity_email" {
  value       = resource.google_service_account.default.email
  description = "Email address of the API gateway identity. Intended for use in config deployments."
}

output "api_id" {
  value = resource.google_api_gateway_api.default.api_id
  description = "Unqualified ID of the API."
}
