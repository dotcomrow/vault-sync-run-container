resource "google_eventarc_trigger" "secret_manager_trigger" {
  name     = "vault-sync-trigger"
  location = var.region
  project  = google_project.project.project_id

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }

  matching_criteria {
    attribute = "serviceName"
    value     = "secretmanager.googleapis.com"
  }

  matching_criteria {
    attribute = "methodName"
    value     = "google.cloud.secretmanager.v1.SecretManagerService.AddSecretVersion"
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.svc.name
      region  = var.region
    }
  }

  service_account = google_service_account.eventarc_service_account.email

  depends_on = [
    google_project_service.project_service,
    google_cloud_run_v2_service.svc
  ]
}

resource "google_pubsub_topic" "secret_manager_events" {
  name    = "${var.project_name}-secret-events"
  project = google_project.project.project_id
}

resource "google_project_iam_member" "eventarc_invoker" {
  project = google_project.project.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_cloud_run_v2_service.svc.template[0].service_account}"
}

resource "google_project_iam_member" "pubsub_subscriber" {
  project = google_project.project.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_cloud_run_v2_service.svc.template[0].service_account}"
}
