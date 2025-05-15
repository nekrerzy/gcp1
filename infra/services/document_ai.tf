module "document_ai" {
  source = "../modules/document_ai"

  project_id            = var.project_id
  location              = var.document_ai_location
  service_account_email = module.pods_service_account.service_account_email

  # Define the processorss
  processors = [
    {
      display_name = "form-parser-${var.environment}"
      type         = "FORM_PARSER_PROCESSOR"
      timeout      = 600
    },
    {
      display_name = "ocr-processor-${var.environment}"
      type         = "OCR_PROCESSOR"
    },
    {
      display_name = "invoice-processor-${var.environment}"
      type         = "INVOICE_PROCESSOR"
    },


  ]

  depends_on = [
    module.api_resources
  ]
}
