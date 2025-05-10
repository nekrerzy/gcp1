output "processor_ids" {
  description = "IDs de los procesadores Document AI creados"
  value = { for k, v in google_document_ai_processor.processor : k => v.name }
}

output "processor_versions" {
  description = "Versiones predeterminadas de los procesadores"
  value = { for k, v in google_document_ai_processor.processor : k => "${v.name}/processorVersions/stable" }
}

output "service_endpoint" {
  description = "Endpoint para consumir Document AI"
  value = "https://${var.location}-documentai.googleapis.com"
}

output "processor_endpoints" {
  description = "Endpoints para procesamiento de documentos (predicción)"
  value = { for k, v in google_document_ai_processor.processor : k => 
    "https://${var.location}-documentai.googleapis.com/v1/projects/${var.project_id}/locations/${var.location}/processors/${split("/", v.name)[length(split("/", v.name))-1]}:process" }
}

output "processor_batch_endpoints" {
  description = "Endpoints para procesamiento por lotes"
  value = { for k, v in google_document_ai_processor.processor : k => 
    "https://${var.location}-documentai.googleapis.com/v1/projects/${var.project_id}/locations/${var.location}/processors/${split("/", v.name)[length(split("/", v.name))-1]}:batchProcess" }
}