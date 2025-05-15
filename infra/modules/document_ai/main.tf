resource "google_document_ai_processor" "processor" {
  for_each = { for idx, p in var.processors : p.display_name => p }

  location     = var.location
  display_name = each.value.display_name
  type         = each.value.type
  project      = var.project_id

}

