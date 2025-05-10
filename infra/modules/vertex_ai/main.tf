

resource "google_vertex_ai_index" "vector_store" {
  region       = var.region
  display_name = "rag-vector-store-genai-dev-gcp101"

  metadata {
    contents_delta_uri = var.vertex_ai_storage_uri
    config {
      dimensions                  = 768
      approximate_neighbors_count = 100

      algorithm_config {
        tree_ah_config {
        }
      }
    }
  }

  index_update_method = "BATCH_UPDATE"


}


data "google_project" "project" {}
resource "google_vertex_ai_index_endpoint" "index_endpoint" {
  display_name = "rag-endpoint"
  description  = "A sample vertex index endpoint"
  region       = var.region
  labels = {
    label-one = "value-one"
  }

  public_endpoint_enabled = false
  network                 = var.network_id

}

