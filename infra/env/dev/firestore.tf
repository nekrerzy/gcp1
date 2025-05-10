module "firestore" {
  source = "../../modules/firestore"

  project_id  = var.project_id
  location_id = var.region # location 1 region for development
  database_id = "dev-firestore"

  collections = [
    "users",
    "products",
    "orders"
  ]

  depends_on = [
    module.api_resources
  ]
}
