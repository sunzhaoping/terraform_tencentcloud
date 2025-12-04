terraform {
  backend "local" {}
  required_providers {
    tencentcloud = {
      source = "tencentcloudstack/tencentcloud"
      version = "~>1.82.40"
    }
  }
}

data "tencentcloud_user_info" "info" {}

locals {
  app_id = data.tencentcloud_user_info.info.app_id
}

provider "tencentcloud" {
  region = "ap-tokyo"
}

resource "tencentcloud_cos_bucket" "tfstate-staging" {
  bucket = "kamihime-terraform-multi-tfstate-staging-${local.app_id}"
  acl    = "private"
  tags = {
    "createdBy" = "terraform"
  }
}

resource "tencentcloud_cos_bucket" "tfstate"{
  bucket = "kamihime-terraform-multi-tfstate-prod-${local.app_id}"
  acl    = "private"
  tags = {
    "createdBy" = "terraform"
  }
}