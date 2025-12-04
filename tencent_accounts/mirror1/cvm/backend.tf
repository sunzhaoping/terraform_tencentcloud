terraform {
  required_version = ">=1.6.6"

  backend "s3" {
    bucket = "kamihime-terraform-multi-tfstate-staging"
    key    = "ec2/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
