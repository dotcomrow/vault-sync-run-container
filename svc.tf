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
    environment = {
      PROJECT_ID         = google_project.project.project_id
      REGION             = var.region
      REPO               = var.project_name
      IMAGE              = var.project_name
      GHCR_USER          = "dotcomrow"
    }

    command = <<EOT
#!/bin/bash

# Download and extract gcloud
curl -sS -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
export PATH="$(pwd)/google-cloud-sdk/bin:$PATH"

# Isolate gcloud + docker config
export CLOUDSDK_CONFIG="$(pwd)/.gcloud"
export DOCKER_CONFIG="$(pwd)/.docker"
mkdir -p "$CLOUDSDK_CONFIG" "$DOCKER_CONFIG"

# Authenticate with GCP
echo "$GOOGLE_CREDENTIALS" > key.json
gcloud auth activate-service-account --key-file=key.json
gcloud config set project "$PROJECT_ID"
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

# Write Docker config.json with gcloud helper
cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "credHelpers": {
    "$REGION-docker.pkg.dev": "gcloud"
  }
}
EOF

# Delete all existing images in the Artifact Registry repo
EXISTING_IMAGES=$(gcloud artifacts docker images list "$REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME/$IMAGE_NAME" --format="get(version)" || true)
for image in $EXISTING_IMAGES; do
  gcloud artifacts docker images delete "$REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME/$IMAGE_NAME@$image" --quiet --delete-tags || true
done

# Pull from GHCR (no auth needed for public image)
docker pull "ghcr.io/$GHCR_USER/$IMAGE_NAME:latest"

# Tag and push to GCP Artifact Registry
docker tag "ghcr.io/$GHCR_USER/$IMAGE_NAME:latest" \
  "$REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME/$IMAGE_NAME:latest"

docker push "$REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME/$IMAGE_NAME:latest"

echo "✅ GHCR image successfully synced to GCP Artifact Registry."
EOT
  }

  depends_on = [
    google_artifact_registry_repository.vault_sync_repo
  ]

  triggers = {
    project     = var.project_name
    image       = var.project_name
    timestamp   = timestamp()
  }
}
