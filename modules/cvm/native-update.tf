resource "aws_security_group" "native-update_sg" {
  name        = "kh-${var.env_name}-native-update-sg"
  description = var.env_name == "prod" ? "kh-${var.env_name}-native-update-sg" : "for_native-update"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.env_name == "prod" ? ["0.0.0.0/0"] : ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kh-${var.env_name}-native-update-sg"
  }
}

resource "aws_eip" "eip-for-native-update" {
  count = startswith(terraform.workspace, "prestage") ? 0 : 1
  domain = "vpc"
}

resource "aws_eip_association" "eip-assoc-native-update" {
  count = startswith(terraform.workspace, "prestage") ? 0 : 1
  instance_id   = aws_instance.native-update.id
  allocation_id = aws_eip.eip-for-native-update[0].id
}

data "aws_ami" "native-update" {
  most_recent = true
  owners      = ["self","185860645449", "amazon"]

  filter {
    name   = "name"
    values = [var.ec2.native-update_ami_name]
  }
}

resource "aws_instance" "native-update" {
  ami           = data.aws_ami.native-update.id
  instance_type = var.ec2.native-update_instance_type

  vpc_security_group_ids = [
    aws_security_group.native-update_sg.id,
  ]

  ebs_optimized = true

  root_block_device {
    iops                  = 3000
    throughput            = 125
    volume_type           = "gp3"
    volume_size           = 500
    delete_on_termination = true
    encrypted             = false
  }

  lifecycle {
    ignore_changes = [vpc_security_group_ids, ami, launch_template] # mirror1環境ではインスタンスが起動テンプレートで作成されてためlaunch_templateを無視する
  }

  iam_instance_profile = "LogstreamEC2PutFirehose"
  subnet_id = startswith(terraform.workspace, "prestage") ? data.aws_subnet.web_subnet_a.id : data.aws_subnet.pub_subnet_a.id

  tags = {
    Name     = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-native-update" : "kh-${var.env_name}-native-update"
    ChefRole = "nginx_static_native_origin"
    HostName = "native-update.local"
    datadog  = "monitored"
    env      = var.env_name
    role     = "native-update"
  }
}

resource "aws_route53_record" "native-update" {
  count   = startswith(terraform.workspace, "prestage") || var.env_name == "mirror1" ? 0 : 1
  zone_id = data.aws_route53_zone.local.id
  name    = "native-update.local"
  type    = "CNAME"
  ttl     = "10"
  records = [aws_instance.native-update.private_dns]
}

resource "aws_route53_record" "native-update_public" {
  count    = startswith(terraform.workspace, "prestage") || contains(["prod", "mirror1"], var.env_name) ? 0 : 1
  zone_id  = data.aws_route53_zone.public.id
  name     = "native-update-${var.env_name}-kh.nurika.be"
  type     = "A"
  ttl      = 60
  records  = [aws_eip.eip-for-native-update[0].public_ip]
}
