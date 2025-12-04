locals {
  expanded_rules = flatten([
    for description, rule in var.provision_sg_rules : [
      for ip in rule.ip : [
        for port in rule.port : {
          description = description
          ip          = ip
          port        = port
        }
      ]
    ]
  ])
}

resource "aws_security_group" "provision_sg" {
  name        = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-provision-sg" : "kh-${var.env_name}-provision-sg"
  description = startswith(terraform.workspace, "prestage") ? "for_provision" : "for_provision_server"
  vpc_id      = data.aws_vpc.vpc.id

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
    Name = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-provision-sg" : "kh-${var.env_name}-provision-sg"
  }
}

resource "aws_security_group_rule" "provision_sg_rules" {
  for_each = {
    for idx, rule in local.expanded_rules :
    "${rule.description}-${rule.ip}-${rule.port}" => rule
  }

  type              = "ingress"
  from_port         = each.value.port
  to_port           = each.value.port
  protocol          = "tcp"
  cidr_blocks       = [each.value.ip]
  description       = each.value.description
  security_group_id = aws_security_group.provision_sg.id
}

data "aws_ami" "provision" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = [var.ec2.provision_ami_name]
  }
}

resource "aws_eip" "eip-for-provision" {
  domain = "vpc"
}

resource "aws_eip_association" "eip-assoc-provision" {
  instance_id   = aws_instance.provision.id
  allocation_id = aws_eip.eip-for-provision.id
}

resource "aws_instance" "provision" {
  ami           = data.aws_ami.provision.id
  instance_type = var.ec2.provision_instance_type
  key_name      = var.ec2.provision_key_name
  vpc_security_group_ids = [
   aws_security_group.provision_sg.id
  ]

  iam_instance_profile = var.ec2.provision_instance_profile

  root_block_device {
    iops                  = 3000
    throughput            = 125
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = false
  }

  subnet_id = data.aws_subnet.pub_subnet_a.id
  tags = {
    Name     = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-provision" : "kh-${var.name}-provision"
    ChefRole = "provision_php80"
    HostName = "provision.local"
    datadog  = "monitored"
    env      = var.env_name
    role     = "provision"
  }

  lifecycle {
    ignore_changes = [
      ami,
      key_name
    ]
  }

}

resource "null_resource" "init_provision_server" {
  depends_on = [aws_instance.provision, aws_eip.eip-for-provision, aws_eip_association.eip-assoc-provision]

  provisioner "remote-exec" {
    inline = [
      "sh -c -e \"sudo hostnamectl set-hostname kh-${var.name}-provision\" ",
      "sed -i -e \"s/export ENV_KEY=.*/export ENV_KEY=${var.env_name}/g\" /home/tx/.bashrc",
    ]

    connection {
      type        = "ssh"
      user        = "tx"
      host        = aws_eip.eip-for-provision.public_ip
      private_key = var.private_key
    }
  }
}

resource "aws_route53_record" "provision" {
  zone_id = data.aws_route53_zone.local.id
  name    = startswith(terraform.workspace, "prestage") ? "${var.env_name}.provision.local" : "provision-php80.local"
  type    = "CNAME"
  ttl     = "10"
  records = [aws_instance.provision.private_dns]
}

resource "aws_route53_record" "provision_public" {
  count    = startswith(terraform.workspace, "prestage") || var.env_name == "prod" ? 0 : 1
  zone_id  = data.aws_route53_zone.public.id
  name     = "provision-php80-${var.env_name}-kh.nurika.be"
  type     = "A"
  ttl      = 60
  records  = [aws_eip.eip-for-provision.public_ip]
}

resource "aws_route53_record" "provision_public_without_php_version" {
  count    = var.env_name == "prod" ? 0 : 1
  zone_id  = data.aws_route53_zone.public.id
  name     = "provision-${var.env_name}-kh.nurika.be"
  type     = var.env_name == "mirror1" ? "CNAME" : "A"
  ttl      = 60
  records  = var.env_name == "mirror1" ? [aws_route53_record.provision_public[0].name] : [aws_eip.eip-for-provision.public_ip]
}
