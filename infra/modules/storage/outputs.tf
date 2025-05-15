
output "bucket_names" {
  description = "The names of the buckets created"
  value       = google_storage_bucket.buckets[*].name
}

output "bucket_urls" {
  description = "The URLs of the buckets created"
  value       = google_storage_bucket.buckets[*].url
}

output "bucket_self_links" {
  description = "The self-links of the buckets created"
  value       = google_storage_bucket.buckets[*].self_link
}

output "buckets_details" {
  description = "Detailed information about each bucket"
  value = [
    for i, bucket in google_storage_bucket.buckets : {
      name               = bucket.name
      url                = bucket.url
      location           = bucket.location
      self_link          = bucket.self_link
      project            = bucket.project
      storage_class      = bucket.storage_class
      versioning_enabled = bucket.versioning[0].enabled
    }
  ]
}
