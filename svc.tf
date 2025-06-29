resource "google_cloud_run_v2_service" "svc" {
  name     = "${var.project_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  project  = "${var.project_name}-${random_id.suffix_gcp.hex}"

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

  depends_on = [ google_project_iam_member.registry_permissions, google_project_iam_member.secret_manager_grant ]
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

curl https://sdk.cloud.google.com > install.sh
bash install.sh --disable-prompts --install-dir=./$dirstring >/dev/null 
PATH=$PATH:./$dirstring/google-cloud-sdk/bin
printf '%s' "$GOOGLE_CREDENTIALS" > key.json
gcloud auth activate-service-account --key-file=key.json

gcloud artifacts repositories create ghcr-proxy \
  --repository-format=docker \
  --location=${var.region} \
  --project=${google_project.project.project_id} \
  --description="Proxy to GitHub Container Registry" \
  --docker-upstream-repository=ghcr.io \
  --quiet
EOT
  }

  triggers = {
    repo = "${google_project.project.project_id}/ghcr-proxy"
  }
}
