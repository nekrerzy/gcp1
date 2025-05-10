<!-- BEGIN_TF_DOCS -->
Storage Module

This module creates Cloud Storage buckets with best practices for
security, lifecycle management, and performance.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_storage_bucket.buckets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.service_account_access](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_buckets"></a> [buckets](#input\_buckets) | List of bucket configurations to create | <pre>list(object({<br/>    name                        = string<br/>    force_destroy               = bool<br/>    uniform_bucket_level_access = bool<br/>    storage_class               = string<br/>    versioning_enabled          = bool<br/>    lifecycle_rules = list(object({<br/>      action_type         = string   # Delete or SetStorageClass<br/>      action_storage_class = string  # Required if action_type is SetStorageClass<br/>      condition_age_days   = number  # Age of object in days<br/>      condition_with_state = string  # "LIVE", "ARCHIVED", "ANY"<br/>    }))<br/>    cors_rules = list(object({<br/>      origins          = list(string)<br/>      methods          = list(string)<br/>      response_headers = list(string)<br/>      max_age_seconds  = number<br/>    }))<br/>    website_config = object({<br/>      main_page_suffix = string<br/>      not_found_page   = string<br/>    })<br/>    labels = map(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_location"></a> [location](#input\_location) | The location for the Cloud Storage buckets | `string` | `"US"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Service account email to grant access to the buckets | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | The names of the buckets created |
| <a name="output_bucket_self_links"></a> [bucket\_self\_links](#output\_bucket\_self\_links) | The self-links of the buckets created |
| <a name="output_bucket_urls"></a> [bucket\_urls](#output\_bucket\_urls) | The URLs of the buckets created |
| <a name="output_buckets_details"></a> [buckets\_details](#output\_buckets\_details) | Detailed information about each bucket |
<!-- END_TF_DOCS -->