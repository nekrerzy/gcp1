output "processor_ids" {
  description = "IDs of the created Document AI processors"
  value       = { for k, v in google_document_ai_processor.processor : k => v.name }
}

output "processor_versions" {
  description = "Default versions of the processors"
  value       = { for k, v in google_document_ai_processor.processor : k => "${v.name}/processorVersions/stable" }
}

output "service_endpoint" {
  description = "Endpoint to consume Document AI"
  value       = "https://${var.location}-documentai.googleapis.com"
}

output "processor_endpoints" {
  description = "Endpoints for document processing (prediction)"
  value = { for k, v in google_document_ai_processor.processor : k =>
  "https://${var.location}-documentai.googleapis.com/v1/projects/${var.project_id}/locations/${var.location}/processors/${split("/", v.name)[length(split("/", v.name)) - 1]}:process" }
}

output "processor_batch_endpoints" {
  description = "Endpoints for batch processing"
  value = { for k, v in google_document_ai_processor.processor : k =>
  "https://${var.location}-documentai.googleapis.com/v1/projects/${var.project_id}/locations/${var.location}/processors/${split("/", v.name)[length(split("/", v.name)) - 1]}:batchProcess" }
}
