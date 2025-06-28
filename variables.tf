variable "region" {
  type        = string
  description = "The region to create the project in"
  nullable = false
}

variable "project_name" {
  description = "The name of the project to create"
  type        = string
  nullable = false
}

variable "project_id" {
  description = "The project id to create"
  type        = string
  nullable = false
}

variable "gcp_org_id" {
  description = "The organization id to create the project under"
  type        = string
  nullable = false
}

variable "apis" {
  description = "The list of apis to enable"  
  type        = list(string)
  default     = [
    "iam.googleapis.com", 
    "cloudresourcemanager.googleapis.com", 
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "cloudbilling.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "containerregistry.googleapis.com",
    "compute.googleapis.com"
  ]
}

variable billing_account {
    description = "The billing account to associate with the project"
    type        = string
    nullable = false
}

variable "common_project_id" {
  description = "Common resources project id"
  type        = string
  nullable = false
}

variable "registry_name" {
  description = "Registry name"
  type        = string
  nullable = false
}

variable "cloudflare_token" {
  description = "cloudflare token"
  type        = string
  nullable = false
}

variable GCP_BIGQUERY_PROJECT_ID {
  description = "GCP bigquery project id"
  type        = string
  nullable = false
}

variable SHARED_SERVICE_ACCOUNT_EMAIL {
  description = "Shared service account email"
  type        = string
  nullable = false
}

variable GCP_LOGGING_PROJECT_ID {
  description = "GCP logging project id"
  type        = string
  nullable = false
}

variable GCP_LOGGING_CREDENTIALS {
  description = "GCP logging credentials"
  type        = string
  nullable = false
}