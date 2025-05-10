#!/usr/bin/env bash
# ------------------------------------------------------------------
# grant_user_roles.sh – Give least-privilege project access
# ------------------------------------------------------------------
#
# Variables you must set before running:
GCP_PROJECT=""       # <-- your project ID
USER_EMAIL=""      # <-- the Google user to grant roles
# ------------------------------------------------------------------

# Roles the user should have
readonly ROLES=(
  roles/viewer                  # read-only visibility across the project
  roles/storage.admin           # full control of GCS buckets/objects
  roles/compute.networkAdmin    # create/modify VPCs, subnets, firewalls
  roles/iam.securityAdmin       # manage IAM bindings (e.g. CI service acct)
  roles/iam.serviceAccountAdmin # Full acces on Service account
  roles/serviceusage.serviceUsageAdmin #Enable apis
  roles/iam.workloadIdentityPoolAdmin
)

for role in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
    --member="user:${USER_EMAIL}" \
    --role="${role}" \
    --quiet
done

echo "✅  Granted roles to ${USER_EMAIL} in ${GCP_PROJECT}"
