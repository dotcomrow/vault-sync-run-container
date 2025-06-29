resource "google_cloud_run_v2_service" "svc" {
  name     = "${var.project_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  project  = "${var.project_name}-${random_id.suffix_gcp.hex}"
  deletion_protection = false

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${google_project.project.project_id}/ghcr-proxy/dotcomrow/vault-sync-run-container:latest"

      env {
        name  = "GCP_BIGQUERY_PROJECT_ID"
        value = var.GCP_BIGQUERY_PROJECT_ID
      }

      env {
        name = "SHARED_SERVICE_ACCOUNT_EMAIL"
        value = var.SHARED_SERVICE_ACCOUNT_EMAIL
      }

      env {
        name = "GCP_LOGGING_CREDENTIALS"
        value = var.GCP_LOGGING_CREDENTIALS
      }

      env {
        name = "GCP_LOGGING_PROJECT_ID"
        value = var.GCP_LOGGING_PROJECT_ID
      }
    }
  }

  depends_on = [ google_project_iam_member.registry_permissions, google_project_iam_member.secret_manager_grant, null_resource.ghcr_proxy_repo ]
}

resource "google_cloud_run_service_iam_policy" "noauth-user-profile" {
  location = google_cloud_run_v2_service.svc.location
  project  = google_cloud_run_v2_service.svc.project
  service  = google_cloud_run_v2_service.svc.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "null_resource" "ghcr_proxy_repo" {
  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash

datenum=$(expr $(date +%s) + 0)
dirstring="$((datenum % 10000))dir"
retries=5
while true; do
  res=$(mkdir $dirstring 2>&1)
  if echo "$res" | grep -Eq '^.{0}$'; then
    break
  fi
  sleep 5
  datenum=$(expr $(date +%s) + 0)
  dirstring="$((datenum % 10000))dir"
  retries=$((retries - 1))
  if [ $retries -eq 0 ]; then
    echo "Failed to create directory"
    exit 1
  fi
done

# Define desired version (472.0.0 or later)
GCLOUD_VERSION=528.0.0
INSTALL_DIR="./$dirstring"

# Download and extract specific SDK version
curl -sSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-$GCLOUD_VERSION-linux-x86_64.tar.gz" | tar -xz -C "$INSTALL_DIR"

# Update PATH to include gcloud CLI
export PATH="$INSTALL_DIR/google-cloud-sdk/bin:$PATH"

# Disable gcloud prompts and install core components
"$INSTALL_DIR/google-cloud-sdk/install.sh" --quiet

# Install gcloud beta CLI to access proxy repo features
gcloud components install beta --quiet

# Activate service account
printf '%s' "$GOOGLE_CREDENTIALS" > key.json
gcloud auth activate-service-account --key-file=key.json

echo 'upstreamPolicies:
  - id: "ghcr"
    upstream: "https://ghcr.io"
    priority: 10' > ghcr-upstream.yaml

cat ghcr-upstream.yaml || exit 1

gcloud artifacts repositories create ghcr-proxy \
  --repository-format=docker \
  --location=us-east1 \
  --project=vault-sync-run-container-9d59 \
  --description="Proxy to GitHub Container Registry" \
  --upstream-policy-file=ghcr-upstream.yaml \
  --format=json \
  --verbosity=debug \
  --quiet
EOT
  }

  triggers = {
    repo = "${google_project.project.project_id}/ghcr-proxy"
  }
}
