#  Create service account
resource "google_service_account" "service_account" {
  account_id   = var.service_account_id
  display_name = var.display_name
  description  = var.description
  project      = var.project_id
}

# Assign IAM roles to the service account
resource "google_project_iam_member" "service_account_roles" {
  for_each = toset(var.roles)
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

