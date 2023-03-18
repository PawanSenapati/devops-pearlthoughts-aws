provider "google" {
  project = "gcp-devops-376307"
  region  = "us-central1"
  zone    = "us-central1-a"
}

variable "image_tag" {
  type = string
}

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

resource "google_cloud_run_service" "app_service" {
  name     = "devops-interview"
  location = "us-central1"
  
  template {
    spec {
      containers {
        image = "gcr.io/gcp-devops-376307/devops-inter:${var.image_tag}"
      }
    }
  }
}
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.app_service.location
  project = "gcp-devops-376307"
  service     = google_cloud_run_service.app_service.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
