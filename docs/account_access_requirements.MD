# IAM Permissions Reference for new GCP Projects using this template

This document captures *who* (service accounts or users) gets *which* IAM roles in the project, plus the rationale behind every grant.  
Use it as the single source of truth when onboarding new teammates or reviewing security posture.

---
## 1  Overview
We attemp to follow **principle of least privilege**: each identity receives only the role set needed to perform its function. broad roles (e.g. `roles/owner`) are avoided.

---
### 1.1  Goals of Each Permission Set
Below is a concise description of *why* each identity exists and the guiding principle behind the roles it receives.

| Identity                   | Primary Goal                                                                                                                                                                                                            |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **GitHub Actions (CI) SA** | Run Terraform/`gcloud` from GitHub workflows to provision, mutate, and tear down infrastructure *autonomously*. Needs broad CRUD plus IAM and API‑enablement powers so the pipeline never pauses for manual privileges. |
| **GKE Node SA**            | Let Autopilot nodes write logs/metrics and securely pull private images. Absolutely no ability to touch other GCP resources.                                                                                            |
| **Pods SA**                | Give in‑cluster workloads the credentials required to store data, call managed AI services, reach Cloud SQL, and rotate secrets—nothing more.                                                                           |
| **ESPv2 SA**               | Allow the Extensible Service Proxy to fetch its OpenAPI config and report telemetry to Service Control (optionally Cloud Trace).                                                                                        |
| **Human User / User SA**   | Provide day‑to‑day operators visibility, storage and network management, and the authority to tweak IAM or enable APIs—without handing over full Owner rights.                                                          |


## 2  Role Matrix

### 2.1  GitHub Actions (CI) Service Account
| Role                                            | Scope   | Why it is needed                                                            |
| ----------------------------------------------- | ------- | --------------------------------------------------------------------------- |
| `roles/compute.admin`                           | project | Create VPC‑SC subnets, forwarding rules, etc.                               |
| `roles/container.admin`                         | project | Provision GKE Autopilot clusters & node pools.                              |
| `roles/storage.admin`                           | project | Create buckets & push build artifacts.                                      |
| `roles/cloudsql.admin`                          | project | Create Cloud SQL instances, users and SSL certs.                            |
| `roles/secretmanager.admin`                     | project | Create application secrets at deploy time.                                  |
| `roles/servicenetworking.networksAdmin`         | project | Add Private Service Connect peerings for Cloud SQL.                         |
| `roles/artifactregistry.admin`                  | project | Create Artifact Registry repos & push images.                               |
| `roles/documentai.admin`                        | project | Provision Document AI processors.                                           |
| `roles/datastore.owner`                         | project | Create Firestore databases (only role with `datastore.databases.create`).   |
| `roles/aiplatform.admin`                        | project | Deploy Vertex AI models & endpoints when needed.                            |
| `roles/servicemanagement.admin`                 | project | Deploy Cloud Endpoints configs (needs `servicemanagement.services.create`). |
| `roles/serviceusage.apiKeysAdmin`               | project | Create & fetch API keys for Endpoints.                                      |
| `roles/iam.serviceAccountAdmin`                 | project | Create additional service accounts.                                         |
| `roles/iam.serviceAccountUser`                  | project | Impersonate service accounts to run Terraform.                              |
| `roles/iam.securityAdmin`                       | project | Grant IAM bindings to new resources.                                        |
| `roles/iam.workloadIdentityPoolAdmin`           | project | Manage GitHub OIDC Workload Identity pool/provider.                         |
| `roles/serviceusage.serviceUsageAdmin`          | project | Enable GCP APIs on‑the‑fly during Terraform runs.                           |
| `roles/dns.admin`                               | project | Manage DNS settings                                                         |
| `roles/iam.serviceAccountKeyAdmin` *(optional)* | project | Only if the pipeline must mint JSON keys.                                   |


> **Least‑privilege tip:** Remove `iam.serviceAccountKeyAdmin` if keys are never required.

### 2.2  GKE Node Service Account
| Role                                        | Scope   | Purpose                                                     |
| ------------------------------------------- | ------- | ----------------------------------------------------------- |
| `roles/container.defaultNodeServiceAccount` | project | Mandatory baseline for Autopilot nodes (metrics + logging). |
| `roles/artifactregistry.reader`             | project | Pull container images from Artifact Registry.               |
| `roles/storage.objectViewer`                | project | Pull images from GCR buckets (legacy).                      |

### 2.3  Pods Service Account
| Role                                        | Scope   | Why                                            |
| ------------------------------------------- | ------- | ---------------------------------------------- |
| `roles/logging.logWriter`                   | project | Emit structured logs directly via Logging API. |
| `roles/storage.admin`                       | project | Read/write GCS objects (data & ML artifacts).  |
| `roles/cloudsql.client`                     | project | Connect to Cloud SQL via IAM Auth Proxy.       |
| `roles/redis.viewer`                        | project | Discover Memorystore connection endpoints.     |
| `roles/aiplatform.user`                     | project | Invoke Vertex AI endpoints.                    |
| `roles/datastore.user`                      | project | CRUD on Firestore collections.                 |
| `roles/documentai.apiUser`                  | project | Call Document AI processors.                   |
| `roles/documentai.viewer`                   | project | Read processor metadata.                       |
| `roles/secretmanager.admin`                 | project | Full secrets lifecycle (rotate at runtime).    |
| `roles/servicemanagement.serviceController` | project | Quota/metrics reporting to Service Control.    |

*Consider aggregating the above into a single custom role for easier auditing.*

### 2.4  ESPv2 Proxy Service Account
| Role                            | Scope   | Purpose                                                                                                              |
| ------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `roles/servicemanagement.admin` | project | Fetch service config & report quota. *(Could be downgraded to `serviceController` if admin abilities are unneeded.)* |

### 2.5  Human User 
| Role                                      | Scope   | Reason                                          |
| ----------------------------------------- | ------- | ----------------------------------------------- |
| `roles/storage.admin`                     | project | Manage build artifacts & data.                  |
| `roles/compute.networkAdmin`              | project | Maintain VPCs, subnets, firewall rules.         |
| `roles/iam.securityAdmin`                 | project | Adjust IAM policies (e.g., grant new CI roles). |
| `roles/iam.serviceAccountAdmin`           | project | Create/delete service accounts as needed.       |
| `roles/serviceusage.serviceUsageAdmin`    | project | Enable additional APIs in the project.          |
| `roles/viewer` *(redundant but harmless)* | project | Read‑only access everywhere.                    |
| `roles/iam.workloadIdentityPoolAdmin`     | project | Workload identitt pools access                  |

---
## 3  Binding Scripts
Below snippets show how we bind roles for each identity. Substitute `CI_SA_EMAIL`, `GCP_PROJECT`, etc.
This is used as part of the `setup` step in the GitHub Actions workflow. in the takeoff script.

```bash
# GitHub Actions SA
for role in \${CI_ROLES[@]}; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
    --member="serviceAccount:${CI_SA_EMAIL}" \
    --role="$role" --quiet
done

# Allow cluster creation to attach node SA
NODE_SA="gke-sa@${GCP_PROJECT}.iam.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding "$NODE_SA" \
  --member="serviceAccount:${CI_SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser" --quiet
```

> **Propagation delay:** IAM changes take up to 60 seconds to propagate; re‑run the pipeline after that.





