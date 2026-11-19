terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.11, < 9"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13, < 1"
    }
  }
}
