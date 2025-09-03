output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "artifact_registry_repository" {
  description = "The Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.flowise_repo.repository_id}"
}

output "storage_bucket_name" {
  description = "The Cloud Storage bucket name"
  value       = google_storage_bucket.flowise_storage.name
}

output "database_instance_name" {
  description = "The Cloud SQL instance name"
  value       = google_sql_database_instance.flowise_db.name
}

output "database_connection_name" {
  description = "The Cloud SQL connection name"
  value       = google_sql_database_instance.flowise_db.connection_name
}

output "database_private_ip_address" {
  description = "The Cloud SQL instance private IP address"
  value       = google_sql_database_instance.flowise_db.private_ip_address
  sensitive   = true
}

output "redis_host" {
  description = "The Redis instance host"
  value       = google_redis_instance.flowise_redis.host
  sensitive   = true
}

output "redis_port" {
  description = "The Redis instance port"
  value       = google_redis_instance.flowise_redis.port
}

output "vpc_connector_name" {
  description = "The VPC Access Connector name"
  value       = google_vpc_access_connector.flowise_connector.name
}

output "secrets_created" {
  description = "List of Secret Manager secrets created"
  value = [
    google_secret_manager_secret.db_host.secret_id,
    google_secret_manager_secret.db_name.secret_id,
    google_secret_manager_secret.db_user.secret_id,
    google_secret_manager_secret.db_password.secret_id,
    google_secret_manager_secret.redis_host.secret_id,
    google_secret_manager_secret.redis_password.secret_id,
    google_secret_manager_secret.jwt_token_secret.secret_id,
    google_secret_manager_secret.jwt_refresh_token_secret.secret_id
  ]
}
