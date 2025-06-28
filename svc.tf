# Create random suffix
resource "random_id" "suffix_gcp" {
  byte_length = 2
}

data "external" "svc-image-sha" {
  program = ["${path.module}/scripts/get-image-sha.sh", "svc-${var.project_name}", "${var.common_project_id}"]
}

resource "null_resource" "build_and_push_image" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/build_and_push_docker.sh"
    environment = {
      PROJECT_NAME = var.project_name
      REGION = var.region
      COMMON_PROJECT_ID = var.common_project_id
      REGISTRY_NAME = var.registry_name
    }
  }

  depends_on = [data.external.svc-image-sha]
}

resource "google_cloud_run_v2_service" "svc" {
  name     = "${var.project_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  project  = "${var.project_name}-${random_id.suffix_gcp.hex}"

  template {
    containers {
      image = "${var.registry_name}/${var.common_project_id}/svc-${var.project_name}@${data.external.svc-image-sha.result["sha"]}"

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

  depends_on = [ google_project_iam_member.registry_permissions, google_project_iam_member.secret_manager_grant, resource.null_resource.build_and_push_image ]
}

resource "google_cloud_run_service_iam_policy" "noauth-user-profile" {
  location = google_cloud_run_v2_service.svc.location
  project  = google_cloud_run_v2_service.svc.project
  service  = google_cloud_run_v2_service.svc.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
