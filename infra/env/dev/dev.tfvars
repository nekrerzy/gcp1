# Dev environment configuration values
project_id   = "" # Replace with your project ID
region       = ""
zone         = ""
network_name = "" # Replace with your desired network name


# Storage configuration
# Replace with your desired bucket names
# and versioning settings
storage_buckets = [
  {
    name = "app-data"
  },
  {
    name               = "app-media"
    versioning_enabled = true
  },
  {
    name               = "vertex-ai-data"
    versioning_enabled = true
  },
  {
    name               = "terraform-state"
    versioning_enabled = true
  },

]
