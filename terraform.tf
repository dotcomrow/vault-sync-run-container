terraform {
  required_providers {
    google = ">= 3.53.0"
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = "${var.cloudflare_token}"
}