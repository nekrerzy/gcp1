<!-- BEGIN_TF_DOCS -->
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
| [google_compute_firewall.rules](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_route.internet_route](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.subnets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_dns_policy.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_auto_create_subnetworks"></a> [auto\_create\_subnetworks](#input\_auto\_create\_subnetworks) | Whether to create auto-mode subnets | `bool` | `false` | no |
| <a name="input_firewall_rules"></a> [firewall\_rules](#input\_firewall\_rules) | List of firewall rules to create | <pre>list(object({<br/>    name        = string<br/>    direction   = string<br/>    priority    = number<br/>    description = string<br/>    ranges      = list(string)<br/>    allow = list(object({<br/>      protocol = string<br/>      ports    = list(string)<br/>    }))<br/>    deny = list(object({<br/>      protocol = string<br/>      ports    = list(string)<br/>    }))<br/>    target_tags        = list(string)<br/>    source_tags        = list(string)<br/>    source_service_accounts = list(string)<br/>    target_service_accounts = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_nat_ip_allocate_option"></a> [nat\_ip\_allocate\_option](#input\_nat\_ip\_allocate\_option) | How external IPs should be allocated for the NAT (AUTO\_ONLY or MANUAL\_ONLY) | `string` | `"AUTO_ONLY"` | no |
| <a name="input_nat_log_config_enable"></a> [nat\_log\_config\_enable](#input\_nat\_log\_config\_enable) | Whether to enable NAT logging | `bool` | `true` | no |
| <a name="input_nat_log_config_filter"></a> [nat\_log\_config\_filter](#input\_nat\_log\_config\_filter) | Specifies the desired filtering of logs (ERRORS\_ONLY, TRANSLATIONS\_ONLY, ALL) | `string` | `"ALL"` | no |
| <a name="input_nat_name"></a> [nat\_name](#input\_nat\_name) | Name of the Cloud NAT configuration | `string` | n/a | yes |
| <a name="input_nat_router_name"></a> [nat\_router\_name](#input\_nat\_router\_name) | Name of the Cloud NAT router | `string` | n/a | yes |
| <a name="input_nat_source_subnetwork_ip_ranges_to_nat"></a> [nat\_source\_subnetwork\_ip\_ranges\_to\_nat](#input\_nat\_source\_subnetwork\_ip\_ranges\_to\_nat) | How NAT should be configured per subnetwork (ALL\_SUBNETWORKS\_ALL\_IP\_RANGES, ALL\_SUBNETWORKS\_ALL\_PRIMARY\_IP\_RANGES, LIST\_OF\_SUBNETWORKS) | `string` | `"ALL_SUBNETWORKS_ALL_IP_RANGES"` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the VPC network | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where resources will be created | `string` | `"us-central1"` | no |
| <a name="input_routing_mode"></a> [routing\_mode](#input\_routing\_mode) | The network routing mode (REGIONAL or GLOBAL) | `string` | `"REGIONAL"` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of subnet configurations (name, cidr, region, secondary\_ranges) | <pre>list(object({<br/>    name          = string<br/>    ip_cidr_range = string<br/>    region        = string<br/>    secondary_ranges = list(object({<br/>      range_name    = string<br/>      ip_cidr_range = string<br/>    }))<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_firewall_rules"></a> [firewall\_rules](#output\_firewall\_rules) | The firewall rule details created |
| <a name="output_nat_ip"></a> [nat\_ip](#output\_nat\_ip) | The external IP addresses used by Cloud NAT |
| <a name="output_nat_name"></a> [nat\_name](#output\_nat\_name) | The name of the Cloud NAT created |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | The ID of the VPC network created |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | The name of the VPC network created |
| <a name="output_network_self_link"></a> [network\_self\_link](#output\_network\_self\_link) | The URI of the VPC network created |
| <a name="output_router_id"></a> [router\_id](#output\_router\_id) | The ID of the router created |
| <a name="output_router_name"></a> [router\_name](#output\_router\_name) | The name of the router created |
| <a name="output_subnets_ids"></a> [subnets\_ids](#output\_subnets\_ids) | The IDs of subnets created |
| <a name="output_subnets_ips"></a> [subnets\_ips](#output\_subnets\_ips) | The IP CIDR ranges of subnets created |
| <a name="output_subnets_names"></a> [subnets\_names](#output\_subnets\_names) | The names of subnets created |
| <a name="output_subnets_regions"></a> [subnets\_regions](#output\_subnets\_regions) | The regions of subnets created |
| <a name="output_subnets_secondary_ranges"></a> [subnets\_secondary\_ranges](#output\_subnets\_secondary\_ranges) | The secondary IP ranges of subnets created |
| <a name="output_subnets_self_links"></a> [subnets\_self\_links](#output\_subnets\_self\_links) | The URIs of subnets created |
<!-- END_TF_DOCS -->