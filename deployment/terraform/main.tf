# Configure Terraform
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "sql-component.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "storage-component.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com"
  ])

  service            = each.key
  disable_on_destroy = false
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "flowise_repo" {
  location      = var.region
  repository_id = "flowise-repo"
  description   = "Flowise container images"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Cloud Storage bucket for file uploads
resource "google_storage_bucket" "flowise_storage" {
  name                        = "${var.project_id}-flowise-storage"
  location                    = var.region
  force_destroy              = true
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Data source to get default VPC network
data "google_compute_network" "default" {
  name = "default"
}

# Private IP range for Google services (using default VPC)
resource "google_compute_global_address" "private_ip_address" {
  name          = "flowise-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.default.id
  
  depends_on = [google_project_service.required_apis]
}

# Private services connection for default VPC
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = data.google_compute_network.default.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  
  depends_on = [google_compute_global_address.private_ip_address]
}

# VPC Access Connector for Cloud Run (using default VPC)
resource "google_vpc_access_connector" "flowise_connector" {
  name          = "flowise-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = data.google_compute_network.default.name
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
  
  depends_on = [google_project_service.required_apis]
}

# Cloud SQL PostgreSQL instance with private IP only
resource "google_sql_database_instance" "flowise_db" {
  name             = "flowise-db-${random_string.db_suffix.result}"
  database_version = "POSTGRES_15"
  region           = var.region
  deletion_protection = false

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_type        = "PD_SSD"
    disk_size        = 20
    disk_autoresize  = true

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      location                      = var.region
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 3
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = data.google_compute_network.default.id
      enable_private_path_for_google_cloud_services = true
      require_ssl                                   = false
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.required_apis
  ]
}

# Generate random suffix for database instance name
resource "random_string" "db_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Database user
resource "google_sql_user" "flowise_user" {
  name     = "flowise"
  instance = google_sql_database_instance.flowise_db.name
  password = random_password.db_password.result
}

# Database
resource "google_sql_database" "flowise_database" {
  name     = "flowise"
  instance = google_sql_database_instance.flowise_db.name
}

# Generate random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Redis instance for queue management
resource "google_redis_instance" "flowise_redis" {
  name           = "flowise-redis"
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size
  region         = var.region

  auth_enabled = true
  
  depends_on = [google_project_service.required_apis]
}

# Secret Manager secrets - Database
resource "google_secret_manager_secret" "db_host" {
  secret_id = "flowise-db-host"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_host" {
  secret = google_secret_manager_secret.db_host.id
  secret_data = google_sql_database_instance.flowise_db.private_ip_address
}

resource "google_secret_manager_secret" "db_name" {
  secret_id = "flowise-db-name"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_name" {
  secret = google_secret_manager_secret.db_name.id
  secret_data = google_sql_database.flowise_database.name
}

resource "google_secret_manager_secret" "db_user" {
  secret_id = "flowise-db-user"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_user" {
  secret = google_secret_manager_secret.db_user.id
  secret_data = google_sql_user.flowise_user.name
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "flowise-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret = google_secret_manager_secret.db_password.id
  secret_data = google_sql_user.flowise_user.password
}

# Secret Manager secrets - Redis
resource "google_secret_manager_secret" "redis_host" {
  secret_id = "flowise-redis-host"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "redis_host" {
  secret = google_secret_manager_secret.redis_host.id
  secret_data = google_redis_instance.flowise_redis.host
}

resource "google_secret_manager_secret" "redis_password" {
  secret_id = "flowise-redis-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "redis_password" {
  secret = google_secret_manager_secret.redis_password.id
  secret_data = google_redis_instance.flowise_redis.auth_string
}

# Secret Manager secrets - JWT Auth
resource "google_secret_manager_secret" "jwt_token_secret" {
  secret_id = "flowise-jwt-token-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "jwt_token_secret" {
  secret = google_secret_manager_secret.jwt_token_secret.id
  secret_data = random_password.jwt_token_secret.result
}

resource "google_secret_manager_secret" "jwt_refresh_token_secret" {
  secret_id = "flowise-jwt-refresh-token-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "jwt_refresh_token_secret" {
  secret = google_secret_manager_secret.jwt_refresh_token_secret.id
  secret_data = random_password.jwt_refresh_token_secret.result
}

# Generate JWT secrets
resource "random_password" "jwt_token_secret" {
  length  = 64
  special = true
}

resource "random_password" "jwt_refresh_token_secret" {
  length  = 64
  special = true
}
