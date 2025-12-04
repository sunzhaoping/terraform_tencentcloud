resource "aws_security_group" "batch_sg" {
  count       = var.env_name == "mirror1" ? 0 : 1
  name        = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-batch-sg" : "kh-${var.env_name}-batch-sg"
  description = startswith(terraform.workspace, "prestage") ? "for_batch" : "kh-${var.env_name}-batch-sg"
  vpc_id      = data.aws_vpc.vpc.id

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
    Name = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-batch-sg" : "kh-${var.env_name}-batch-sg"
  }
}

data "aws_ami" "batch" {
  count = var.env_name == "mirror1" ? 0 : 1
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [var.ec2.batch_ami_name]
  }
}

resource "aws_instance" "batch" {
  count         = var.env_name == "mirror1" ? 0 : 1
  ami           = data.aws_ami.batch[0].id
  instance_type = var.ec2.batch_instance_type
  vpc_security_group_ids = [
    aws_security_group.batch_sg[0].id,
  ]

  ebs_optimized = startswith(terraform.workspace, "prestage") && terraform.workspace != "prestage2" ? false : true

  iam_instance_profile = "LogstreamEC2PutFirehose"
  subnet_id            = data.aws_subnet.web_subnet_a.id

  root_block_device {
    iops                  = 3000
    throughput            = 125
    volume_type           = "gp3"
    volume_size           = 40
    delete_on_termination = true
    encrypted             = false
  }
  
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name     = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-batch" : "kh-${var.name}-batch${var.env_name == "mirror1" ? "" : "-01"}"
    ChefRole = "batch_master_php80"
    HostName = startswith(terraform.workspace, "prestage") ? "${var.env_name}.batch.local" : "batch.local"
    datadog  = "monitored"
    env      = var.env_name
    role     = "batch"
  }
}

resource "aws_route53_record" "batch" {
  count   = var.env_name == "mirror1" ? 0 : 1
  zone_id = data.aws_route53_zone.local.id
  name    = startswith(terraform.workspace, "prestage") ? "${var.env_name}.batch.local" : "batch-php80.local"
  type    = "CNAME"
  ttl     = "10"
  records = [aws_instance.batch[0].private_dns]
}
