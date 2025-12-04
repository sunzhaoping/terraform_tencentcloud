resource "aws_security_group" "nodejs_sg" {
  name        = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-nodejs-sg" : "kh-${var.env_name}-nodejs-sg"
  description = startswith(terraform.workspace, "prestage") ? "for_nodejs" : "for_nodejs_server"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  ingress {
    from_port   = 3001
    to_port     = 3020
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
    Name = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-nodejs-sg" : "kh-${var.env_name}-nodejs-sg"
  }
}

data "aws_ami" "nodejs" {
  most_recent = true
  owners      = ["self","185860645449"]

  filter {
    name   = "name"
    values = [var.ec2.nodejs_ami_name]
  }
}

resource "aws_instance" "nodejs_a" {
  count         = var.ec2.nodejs_count
  ami           = data.aws_ami.nodejs.id
  instance_type = var.ec2.nodejs_instance_type

  vpc_security_group_ids = [
    aws_security_group.nodejs_sg.id,
  ]

  iam_instance_profile = "LogstreamEC2PutFirehose"
  subnet_id     = startswith(terraform.workspace, "prestage") ? data.aws_subnet.web_subnet_a.id : data.aws_subnet.nodejs_subnet_a.id
  ebs_optimized = startswith(terraform.workspace, "prestage") && terraform.workspace != "prestage2" ? false : true

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
    Name     = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-nodejs" : "kh-${var.env_name}-nodejs-a${count.index + 1}"
    ChefRole = "nodejs"
    HostName = startswith(terraform.workspace, "prestage") ? "${var.env_name}.nodejs_a${count.index + 1}.local" : "nodejs_a${count.index + 1}.local"
    datadog  = "monitored"
    env      = var.env_name
    role     = "nodejs"
  }
}

resource "aws_route53_record" "nodejs_a" {
  count   = var.env_name == "mirror1" ? 0 : var.ec2.nodejs_count
  zone_id = data.aws_route53_zone.local.id
  name    = startswith(terraform.workspace, "prestage") ? "${var.env_name}.nodejs.local" : "nodejs_a${count.index + 1}.local"
  type    = "CNAME"
  ttl     = "10"
  records = [element(aws_instance.nodejs_a.*.private_dns, count.index)]
}

resource "aws_instance" "nodejs_c" {
  count         = var.env_name == "prod" ? var.ec2.nodejs_count : 0
  ami           = data.aws_ami.nodejs.id
  instance_type = var.ec2.nodejs_instance_type

  vpc_security_group_ids = [
    aws_security_group.nodejs_sg.id,
  ]

  iam_instance_profile = "LogstreamEC2PutFirehose"
  subnet_id = data.aws_subnet.nodejs_subnet_c.id
  ebs_optimized = startswith(terraform.workspace, "prestage") || contains(["prod", "mirror1"], var.env_name) ? true : false

  root_block_device {
    iops                  = 3000
    throughput            = 125
    volume_type           = "gp3"
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name     = "kh-${var.env_name}-nodejs-c${count.index + 1}"
    ChefRole = "nodejs"
    HostName = "nodejs_c${count.index + 1}.local"
    datadog  = "monitored"
    env      = var.env_name
    role     = "nodejs"
  }
}

resource "aws_route53_record" "nodejs_c" {
  count   = var.env_name == "prod" ? var.ec2.nodejs_count : 0
  zone_id = data.aws_route53_zone.local.id
  name    = "nodejs_c${count.index + 1}.local"
  type    = "CNAME"
  ttl     = "10"
  records = [element(aws_instance.nodejs_c.*.private_dns, count.index)]
}
