
output "vertex_ai_endpoint_id" {
  description = "The ID of the Vertex AI endpoint."
  value       = google_vertex_ai_index_endpoint.index_endpoint.id
}
output "vertex_ai_index_id" {
  description = "The ID of the Vertex AI index."
  value       = google_vertex_ai_index.vector_store.id
}
output "vertex_ai_index_endpoint_id" {
  description = "The ID of the Vertex AI index endpoint."
  value       = google_vertex_ai_index_endpoint.index_endpoint.id
}
output "vertex_ai_index_endpoint_url" {
  description = "The URL of the Vertex AI index endpoint."
  value       = google_vertex_ai_index_endpoint.index_endpoint
}

