module "cloud_sql" {
  source = "../../modules/cloud_sql"


  project_id      = var.project_id
  region          = var.region
  network_id      = module.networking.network_id
  private_network = module.networking.network_self_link


  instance_name = "psql-${var.project_id}-${var.environment}-${var.unique_suffix}"
  database_name = "postgres-genai-${var.environment}-${var.unique_suffix}"
  user_name     = "app_user"


  database_version    = "POSTGRES_17"
  disk_size           = 30
  tier                = var.environment == "dev" ? "db-custom-2-4096" : "db-perf-optimized-N-4"
  availability_type   = var.environment == "dev" ? "ZONAL" : "REGIONAL"
  edition             = var.environment == "dev" ? "ENTERPRISE" : "ENTERPRISE_PLUS"
  backup_enabled      = true # Keep backups on even for dev
  deletion_protection = var.environment == "prod" ? false : false

  depends_on = [
    module.networking,
    google_service_networking_connection.private_vpc_connection
  ]
}






resource "google_secret_manager_secret" "db-user" {
  secret_id = "db-user-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [module.api_resources]
}

resource "google_secret_manager_secret_version" "db-user-version" {
  secret      = google_secret_manager_secret.db-user.id
  secret_data = module.cloud_sql.user_name
  depends_on  = [module.api_resources]
}

resource "google_secret_manager_secret" "db-password" {
  secret_id = "db-password-${var.environment}"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [module.api_resources]
}

resource "google_secret_manager_secret_version" "db-password-version" {
  secret      = google_secret_manager_secret.db-password.id
  secret_data = module.cloud_sql.user_password
  depends_on  = [module.api_resources]
}

resource "google_secret_manager_secret" "db-name" {
  secret_id = "db-name-${var.environment}"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [module.api_resources]
}

resource "google_secret_manager_secret_version" "db-name-version" {
  secret      = google_secret_manager_secret.db-name.id
  secret_data = var.db_name
  depends_on  = [module.api_resources]
}

resource "google_secret_manager_secret" "db-instance-connection-name" {
  secret_id = "db-instance-connection-name-${var.environment}"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [module.api_resources]
}

resource "google_secret_manager_secret_version" "db-instance-connection-name-version" {
  secret      = google_secret_manager_secret.db-instance-connection-name.id
  secret_data = module.cloud_sql.instance_connection_name
  depends_on  = [module.api_resources]
}
