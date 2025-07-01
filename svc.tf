resource "google_cloud_run_v2_service" "svc" {
  name     = "${var.project_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  project  = "${var.project_name}-${random_id.suffix_gcp.hex}"
  deletion_protection = false

  template {
    containers {
      image = "ghcr.io/dotcomrow/${var.project_name}:latest"

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

  depends_on = [
    google_project_iam_member.registry_permissions,
    google_project_iam_member.secret_manager_grant,
    null_resource.ghcr_to_gcp_image_sync,
    google_artifact_registry_repository.vault_sync_repo
  ]
}

resource "google_cloud_run_service_iam_policy" "noauth-user-profile" {
  location = google_cloud_run_v2_service.svc.location
  project  = google_cloud_run_v2_service.svc.project
  service  = google_cloud_run_v2_service.svc.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_artifact_registry_repository" "vault_sync_repo" {
  location        = var.region
  repository_id   = "vault-sync-run-container"
  format          = "DOCKER"
  project         = google_project.project.project_id
  description     = "Hosted repo for vault-sync image"
}

resource "null_resource" "ghcr_to_gcp_image_sync" {
  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash

PROJECT_ID="${google_project.project.project_id}"

# Download and install Google Cloud SDK
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh

# Authenticate to GCP
printf '%s' "$GOOGLE_CREDENTIALS" > key.json
./google-cloud-sdk/bin/gcloud auth activate-service-account --key-file=key.json
./google-cloud-sdk/bin/gcloud config set project "$PROJECT_ID"
./google-cloud-sdk/bin/gcloud auth configure-docker "${var.region}-docker.pkg.dev" --quiet

# Debug auth
echo "🔐 Docker config:"
cat ~/.docker/config.json || echo "⚠️ Docker config not found"

# Delete existing images in Artifact Registry
EXISTING_IMAGES=$(./google-cloud-sdk/bin/gcloud artifacts docker images list \
  "${var.region}-docker.pkg.dev/$PROJECT_ID/${var.project_name}/${var.project_name}" --format="get(version)")

if [ -n "$EXISTING_IMAGES" ]; then
  for image in $EXISTING_IMAGES; do
    ./google-cloud-sdk/bin/gcloud artifacts docker images delete \
      "${var.region}-docker.pkg.dev/$PROJECT_ID/${var.project_name}/${var.project_name}@$image" \
      --quiet --delete-tags || true
  done
else
  echo "🗑️ No images to delete."
fi

# Pull from GHCR
docker pull "ghcr.io/dotcomrow/${var.project_name}:latest"

# Tag for GCP
docker tag "ghcr.io/dotcomrow/${var.project_name}:latest" \
  "${var.region}-docker.pkg.dev/$PROJECT_ID/${var.project_name}/${var.project_name}:latest"

# Push to GCP Artifact Registry
docker push "${var.region}-docker.pkg.dev/$PROJECT_ID/${var.project_name}/${var.project_name}:latest"

echo "✅ GHCR image synced to Artifact Registry."
EOT
  }

  triggers = {
    force_run = timestamp()
  }
}
