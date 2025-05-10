output "api_enablement_complete" {
  description = "Flag to indicate API enablement is complete"
  value       = time_sleep.api_enablement.id
}