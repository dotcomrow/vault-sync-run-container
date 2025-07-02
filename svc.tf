resource "google_cloud_run_v2_service" "svc" {
  name     = "${var.project_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  project  = "${google_project.project.project_id}"
  deletion_protection = false

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${google_project.project.project_id}/${var.project_name}/${var.project_name}:latest"

      env {
        name  = "GCP_PROJECT_ID"
        value = google_project.project.project_id
      }

      env {
        name  = "VAULT_ADDR"
        value = var.VAULT_ADDRESS
      }

      env {
        name  = "VAULT_ROLE_ID"
        value = var.VAULT_ROLE_ID
      }

      env {
        name  = "VAULT_SECRET_ID"
        value = var.VAULT_SECRET_ID
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
      GHCR_USER   = "dotcomrow"
      IMAGE_NAME  = var.project_name
      REGION      = var.region
      PROJECT_ID  = google_project.project.project_id
    }

    command = <<-EOT
      #!/bin/bash

      # Setup directories for isolated gcloud and docker configs
      export CLOUDSDK_CONFIG="$(pwd)/.gcloud"
      export DOCKER_CONFIG="$(pwd)/.docker"
      mkdir -p "$CLOUDSDK_CONFIG" "$DOCKER_CONFIG"

      # Download gcloud SDK and configure PATH
      curl -sS -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
      tar -xf google-cloud-cli-linux-x86_64.tar.gz
      export PATH="$(pwd)/google-cloud-sdk/bin:$PATH"

      # Authenticate with GCP
      printf "%s" "$GOOGLE_CREDENTIALS" > key.json
      gcloud auth activate-service-account --key-file=key.json
      gcloud config set project "$PROJECT_ID"

      # ✅ Login to Artifact Registry directly
      echo "$(gcloud auth print-access-token)" | docker login -u oauth2accesstoken --password-stdin https://$REGION-docker.pkg.dev
      gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

      # Delete all images in Artifact Registry repo (digests + tags)
      REPO_PATH="$REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME"
      EXISTING_IMAGES=$(gcloud artifacts docker images list "$REPO_PATH" --format="get(version)" || true)
      for image in $EXISTING_IMAGES; do
        gcloud artifacts docker images delete "$REPO_PATH@$image" --quiet --delete-tags || true
      done

      # Pull from GHCR
      docker pull "ghcr.io/$GHCR_USER/$IMAGE_NAME:latest"

      # Tag and push to GCP Artifact Registry
      docker tag "ghcr.io/$GHCR_USER/$IMAGE_NAME:latest" \
        "$REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME/$IMAGE_NAME:latest"

      docker push "$REGION-docker.pkg.dev/$PROJECT_ID/$IMAGE_NAME/$IMAGE_NAME:latest"

      echo "✅ GHCR image successfully synced to GCP Artifact Registry."
    EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}
