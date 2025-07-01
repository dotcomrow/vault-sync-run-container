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

echo "🔧 Installing gcloud..."
curl -sS -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh --quiet

echo "🔐 Authenticating to GCP..."
printf '%s' "$GOOGLE_CREDENTIALS" > key.json
./google-cloud-sdk/bin/gcloud auth activate-service-account --key-file=key.json
./google-cloud-sdk/bin/gcloud config set project "$PROJECT_ID"
./google-cloud-sdk/bin/gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

echo "🧹 Deleting old images..."
EXISTING_IMAGES=$(./google-cloud-sdk/bin/gcloud artifacts docker images list \
  "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/$IMAGE" --format="get(version)" || true)

if [ -n "$EXISTING_IMAGES" ]; then
  for image in $EXISTING_IMAGES; do
    ./google-cloud-sdk/bin/gcloud artifacts docker images delete \
      "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/$IMAGE@$image" \
      --quiet --delete-tags || true
  done
else
  echo "🗑️ No existing images to delete."
fi

echo "🐳 Pulling image from GHCR..."
docker pull "ghcr.io/$GHCR_USER/$IMAGE:latest"

echo "🏷️ Tagging for GCP Artifact Registry..."
docker tag "ghcr.io/$GHCR_USER/$IMAGE:latest" \
  "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/$IMAGE:latest"

echo "📤 Pushing to Artifact Registry..."
docker push "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/$IMAGE:latest"

echo "✅ GHCR image synced to GCP Artifact Registry."
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
