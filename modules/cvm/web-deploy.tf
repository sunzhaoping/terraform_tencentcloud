resource "aws_security_group" "web_sg" {
  name        = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-web-sg" : "kh-${var.env_name}-web-sg"
  description = startswith(terraform.workspace, "prestage") ? "for_web" : "for_web_server"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  lifecycle {
    ignore_changes = [description]
  }

  tags = {
    Name = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-web-sg" : "kh-${var.env_name}-web-sg"
  }
}

data "aws_ami" "web-deploy" {
  count       = var.ec2.create_web_deploy ? 1 : 0
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [var.ec2.web-deploy_ami_name]
  }
}

resource "aws_instance" "web-deploy" {
  count         = var.ec2.create_web_deploy ? 1 : 0
  ami           = data.aws_ami.web-deploy[0].id
  instance_type = var.ec2.web-deploy_instance_type

  ebs_optimized = true

  vpc_security_group_ids = [
   aws_security_group.web_sg.id
  ]

  iam_instance_profile = "LogstreamEC2PutFirehose"
  subnet_id            = data.aws_subnet.web_subnet_a.id

  tags = {
    Name     = "kh-${var.name}-web-deploy"
    ChefRole = "web_php80"
    HostName = startswith(terraform.workspace, "prestage") ? "${var.env_name}.web-deploy.local" : "web-deploy.local"
    datadog  = "monitored"
    env      = var.env_name
    role     = "web-deploy"
  }

  lifecycle {
    ignore_changes = [ami]
}
  root_block_device {
    tags        = {}
    volume_size = 100
    volume_type = "gp3"
    iops = 3000
    throughput = 125
  }
}

resource "aws_route53_record" "web-deploy" {
  count   = var.ec2.create_web_deploy ? 1 : 0
  zone_id = data.aws_route53_zone.local.id
  name    = startswith(terraform.workspace, "prestage") ? "${var.env_name}.web-deploy.local" : "web-deploy-php80.local"
  type    = "CNAME"
  ttl     = "10"
  records = [aws_instance.web-deploy[0].private_dns]
}
