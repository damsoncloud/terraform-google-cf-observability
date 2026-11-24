terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
