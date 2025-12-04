resource "aws_security_group" "control_sg" {
  count       = var.env_name == "mirror1" ? 0 : 1
  name        = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-control-sg" : "kh-${var.env_name}-control-sg"
  description = "for_control"
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
    Name = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-control-sg" : "kh-${var.env_name}-control-sg"
  }
}

data "aws_ami" "control" {
  count = var.env_name == "mirror1" ? 0 : 1
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [var.ec2.control_ami_name]
  }
}

resource "aws_instance" "control" {
  count         = var.env_name == "mirror1" ? 0 : 1
  ami           = data.aws_ami.control[0].id
  instance_type = var.ec2.control_instance_type
  vpc_security_group_ids = [
    aws_security_group.control_sg[0].id
  ]

  ebs_optimized = startswith(terraform.workspace, "prestage") && terraform.workspace != "prestage2" ? false : true
  iam_instance_profile = "LogstreamEC2PutFirehose"
  subnet_id            = data.aws_subnet.web_subnet_a.id

  lifecycle {
    ignore_changes = [ami]
  }

  root_block_device {
    iops                  = 3000
    throughput            = 125
    volume_type           = "gp3"
    volume_size           = 40
    delete_on_termination = true
    encrypted             = false
  }

  tags = {
    Name     = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-control" : "kh-${var.name}-control"
    ChefRole = "control_php80"
    HostName = startswith(terraform.workspace, "prestage") ? "${var.env_name}.control.local" : "control.local"
    datadog  = "monitored"
    env      = var.env_name
    role     = "control"
  }
}

resource "aws_route53_record" "control" {
  count   = var.env_name == "mirror1" ? 0 : 1
  zone_id = data.aws_route53_zone.local.id
  name    = startswith(terraform.workspace, "prestage") ? "${var.env_name}.control.local" : "control-php80.local"
  type    = "CNAME"
  ttl     = "10"
  records = [aws_instance.control[0].private_dns]
}
