<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_sql_database.database](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_database_instance.instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [random_password.user_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_type"></a> [availability\_type](#input\_availability\_type) | The availability type for the Cloud SQL instance (REGIONAL for HA or ZONAL for single zone) | `string` | `"REGIONAL"` | no |
| <a name="input_backup_enabled"></a> [backup\_enabled](#input\_backup\_enabled) | Whether backups are enabled | `bool` | `true` | no |
| <a name="input_backup_start_time"></a> [backup\_start\_time](#input\_backup\_start\_time) | The start time for backups in format 'HH:MM' | `string` | `"02:00"` | no |
| <a name="input_database_flags"></a> [database\_flags](#input\_database\_flags) | Database flags to set | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | The name of the default database to create | `string` | `"app_db"` | no |
| <a name="input_database_version"></a> [database\_version](#input\_database\_version) | The database version to use | `string` | `"POSTGRES_17"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether deletion protection is enabled | `bool` | `true` | no |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | The size of the disk in GB | `number` | `10` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | The type of disk (PD\_SSD or PD\_HDD) | `string` | `"PD_SSD"` | no |
| <a name="input_edition"></a> [edition](#input\_edition) | The Cloud SQL edition to use (ENTERPRISE or ENTERPRISE\_PLUS) | `string` | `"ENTERPRISE"` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | The name of the Cloud SQL instance | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | The VPC network ID where the Cloud SQL instance will be connected | `string` | n/a | yes |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | The VPC network to peer with the Cloud SQL instance | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where the Cloud SQL instance will be created | `string` | n/a | yes |
| <a name="input_tier"></a> [tier](#input\_tier) | The machine type to use | `string` | `"db-g1-small"` | no |
| <a name="input_user_name"></a> [user\_name](#input\_user\_name) | The name of the default user to create | `string` | `"postgres"` | no |
| <a name="input_user_password"></a> [user\_password](#input\_user\_password) | The password for the default user (leave blank to auto-generate) | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_string"></a> [connection\_string](#output\_connection\_string) | The connection string to use to connect to the PostgreSQL instance |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | The name of the database |
| <a name="output_instance_connection_name"></a> [instance\_connection\_name](#output\_instance\_connection\_name) | The connection name of the instance to be used in connection strings |
| <a name="output_instance_first_ip_address"></a> [instance\_first\_ip\_address](#output\_instance\_first\_ip\_address) | The first IPv4 address of the addresses assigned |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | The ID of the Cloud SQL instance |
| <a name="output_instance_ip_address"></a> [instance\_ip\_address](#output\_instance\_ip\_address) | The IPv4 address of the instance |
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name) | The name of the Cloud SQL instance |
| <a name="output_instance_self_link"></a> [instance\_self\_link](#output\_instance\_self\_link) | The URI of the instance |
| <a name="output_instance_server_ca_cert"></a> [instance\_server\_ca\_cert](#output\_instance\_server\_ca\_cert) | The CA certificate information used to connect to the database instance |
| <a name="output_user_name"></a> [user\_name](#output\_user\_name) | The name of the user |
| <a name="output_user_password"></a> [user\_password](#output\_user\_password) | The password of the user |
<!-- END_TF_DOCS -->