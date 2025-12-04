resource "aws_security_group" "nginx-img-amzn2_sg" {
  name        = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-nginx-img-amzn2-sg" : "kh-${var.env_name}-${var.env_name == "mirror1" ? "nginx-img-sg" : "nginx-img-amzn2-sg"}" 
  description = var.env_name == "mirror1" ? "for_nginx-img_server" : "for_nginx-img-amzn2_server"
  vpc_id      = data.aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-nginx-img-amzn2-sg" : "kh-${var.env_name}-${var.env_name == "mirror1" ? "nginx-img-sg" : "nginx-img-amzn2-sg"}"  }
}

resource "aws_security_group_rule" "nginx-img-amzn2_sg_22" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.nginx-img-amzn2_sg.id
}

resource "aws_security_group_rule" "nginx-img-amzn2_sg_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.env_name == "prod" ? ["0.0.0.0/0"] : ["10.0.0.0/16"]
  security_group_id = aws_security_group.nginx-img-amzn2_sg.id
}

resource "aws_security_group_rule" "nginx-img-amzn2_sg_8888" {
  count             = var.env_name == "prod" ? 1 : 0
  type              = "ingress"
  from_port         = 8888
  to_port           = 8888
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nginx-img-amzn2_sg.id
}

resource "aws_eip" "eip-for-nginx-img-amzn2" {
  count = startswith(terraform.workspace, "prestage") || var.env_name == "mirror1" ? 0 : 1
  domain = "vpc"
}

resource "aws_eip_association" "eip-assoc-nginx-img-amzn2" {
  count = startswith(terraform.workspace, "prestage") || var.env_name == "mirror1" ? 0 : 1
  instance_id   = aws_instance.nginx-img-amzn2.id
  allocation_id = aws_eip.eip-for-nginx-img-amzn2[0].id
}

data "aws_ami" "nginx-img-amzn2" {
  most_recent = true
  owners      = ["self","185860645449"]

  filter {
    name   = "name"
    values = [var.ec2.nginx-img-amzn2_ami_name]
  }
}

resource "aws_instance" "nginx-img-amzn2" {
  ami           = data.aws_ami.nginx-img-amzn2.id
  instance_type = var.ec2.nginx-img-amzn2_instance_type

  vpc_security_group_ids = [
    aws_security_group.nginx-img-amzn2_sg.id
  ]

  lifecycle {
    ignore_changes = [vpc_security_group_ids, ami]
  }

  iam_instance_profile = "LogstreamEC2PutFirehose"
  subnet_id = startswith(terraform.workspace, "pre") ? data.aws_subnet.web_subnet_a.id : data.aws_subnet.pub_subnet_a.id
  ebs_optimized = startswith(terraform.workspace, "pre") || contains(["prod", "mirror1"], var.env_name) ? true : false
  tags = {
    Name     = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-nginx-img-amzn2" : "kh-${var.env_name}-nginx-img-amzn2${var.env_name == "mirror1" ? "" : "-01"}"
    ChefRole = "nginx_static_origin"
    HostName = "nginx-img-amzn2.local"
    datadog  = "monitored"
    env      = var.env_name
    role     = "nginx-img-amzn2"
  }
}

resource "aws_route53_record" "nginx-img-amzn2" {
  count   = startswith(terraform.workspace, "prestage") || var.env_name == "mirror1" ? 0 : 1
  zone_id = data.aws_route53_zone.local.id
  name    = "nginx-img-amzn2.local"
  type    = "CNAME"
  ttl     = "10"
  records = [aws_instance.nginx-img-amzn2.private_dns]
}

resource "aws_route53_record" "nginx-img-amzn2_public" {
  count    = startswith(terraform.workspace, "prestage") || contains(["prod", "mirror1"], var.env_name) ? 0 : 1
  zone_id  = data.aws_route53_zone.public.id
  name     = "nginx-img-amzn2-${var.env_name}-kh.nurika.be"
  type     = "A"
  ttl      = 60
  records  = [aws_eip.eip-for-nginx-img-amzn2[0].public_ip]
}
