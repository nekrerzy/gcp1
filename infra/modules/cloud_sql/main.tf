
# Generate a random password for the database user if none is provided
resource "random_password" "user_password" {
  length           = 12
  special          = true
  override_special = "_-.#"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}


# Create the Cloud SQL instance
resource "google_sql_database_instance" "instance" {
  name             = var.instance_name
  region           = var.region
  database_version = var.database_version
  project          = var.project_id

  #deletion_protection = var.deletion_protection


  # Instance settings
  settings {
    tier              = var.tier
    edition           = var.edition
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = var.disk_type



    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.backup_enabled
    }


    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "-1"
    }
    database_flags {
      name  = "log_min_messages"
      value = "warning"
    }
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
    database_flags {
      name  = "max_connections"
      value = "100"
    }



    maintenance_window {
      day          = 7 # Sunday
      hour         = 2 # 2 AM
      update_track = "stable"
    }

    # Configure private IP
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.private_network
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"


    }

    # Configure insights
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 4096
      record_application_tags = true
      record_client_address   = false
    }

    # Best practices for security
    password_validation_policy {
      enable_password_policy      = true
      min_length                  = 8
      complexity                  = "COMPLEXITY_DEFAULT"
      reuse_interval              = 5
      disallow_username_substring = true

    }
  }

  # Depend on the network to ensure the VPC and networking is available
  depends_on = [
    var.network_id,

  ]
}

# Create a database
resource "google_sql_database" "database" {
  name      = var.database_name
  instance  = google_sql_database_instance.instance.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
  project   = var.project_id
}

# Create a user
resource "google_sql_user" "user" {
  name     = var.user_name
  instance = google_sql_database_instance.instance.name
  password = var.user_password != "" ? var.user_password : random_password.user_password.result
  project  = var.project_id

  # Avoid user recreation on password change
  deletion_policy = "ABANDON"


}

