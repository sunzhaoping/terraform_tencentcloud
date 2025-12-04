data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values =  [startswith(terraform.workspace, "pre") ? "kh-shared-prestage-vpc" : "kh-${terraform.workspace}-vpc"]
  }
}

data "aws_subnet" "pub_subnet_a" {
  filter {
    name   = "tag:Name"
    values = [startswith(terraform.workspace, "pre") ? "kh-shared-prestage-pub-subnet-a" : "kh-${terraform.workspace}-pub-subnet-a"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnet" "web_subnet_a" {

  filter {
    name   = "tag:Name"
    values = [startswith(terraform.workspace, "pre") ? "kh-shared-prestage-web-subnet-a" : "kh-${terraform.workspace}-web-subnet-a"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnet" "web_subnet_c" {

  filter {
    name   = "tag:Name"
    values = [startswith(terraform.workspace, "pre") ? "kh-shared-prestage-web-subnet-c" : "kh-${terraform.workspace}-web-subnet-c"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnet" "nodejs_subnet_a" {

  filter {
    name   = "tag:Name"
    values = [startswith(terraform.workspace, "pre") ? "kh-shared-prestage-nodejs-subnet-a" : "kh-${terraform.workspace}-nodejs-subnet-a"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnet" "nodejs_subnet_c" {

  filter {
    name   = "tag:Name"
    values = [startswith(terraform.workspace, "pre") ? "kh-shared-prestage-nodejs-subnet-c" : "kh-${terraform.workspace}-nodejs-subnet-c"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnet" "elb_subnet_a" {

  filter {
    name   = "tag:Name"
    values = [startswith(terraform.workspace, "pre") ? "kh-shared-prestage-elb-subnet-a" : "kh-${terraform.workspace}-elb-subnet-a"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnet" "elb_subnet_c" {

  filter {
    name   = "tag:Name"
    values = [startswith(terraform.workspace, "pre") ? "kh-shared-prestage-elb-subnet-c" : "kh-${terraform.workspace}-elb-subnet-c"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_route53_zone" "local" {
  name         = "local"
  private_zone = true
  vpc_id       = data.aws_vpc.vpc.id
}

data "aws_route53_zone" "public" {
  name         = var.env_name == "prod" ? "kamihimeproject.net" : "nurika.be"
}
