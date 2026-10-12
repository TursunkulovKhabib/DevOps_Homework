terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.9"
    }
  }

  # State хранится локально в terraform.tfstate (в .gitignore).
  # В команде его выносят в удалённый backend (S3/GitLab) с блокировкой.
  backend "local" {
    path = "terraform.tfstate"
  }
}
