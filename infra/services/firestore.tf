module "firestore" {
  source = "../modules/firestore"

  project_id  = var.project_id
  location_id = var.region # location 1 region for development
  database_id = "${var.environment}-firestore"

  collections = var.firestore_collections

  depends_on = [
    module.api_resources
  ]
}
