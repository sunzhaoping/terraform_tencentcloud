resource "aws_security_group" "web-alb_sg" {
  name        = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-web-alb-sg" : "kh-${var.env_name}-web-alb-sg"
  description = "for_web-alb"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-web-alb-sg" : "kh-${var.env_name}-web-alb-sg"
  }
}

resource "aws_alb" "web-alb1" {
  name            = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-web-alb1" : "kh-${var.env_name}-web-alb"
  internal        = false
  enable_cross_zone_load_balancing = true
  security_groups = [aws_security_group.web-alb_sg.id]
  subnets = [
    data.aws_subnet.elb_subnet_a.id,
    data.aws_subnet.elb_subnet_c.id
  ]
  enable_deletion_protection = false
}

resource "aws_alb_listener" "nodejs-listener1" {
  load_balancer_arn = aws_alb.web-alb1.arn
  port              = "3001"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = var.ec2.certificate_arn
  default_action {
    target_group_arn = aws_alb_target_group.nodejs-tg1.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group" "nodejs-tg1" {
  name     = startswith(terraform.workspace, "prestage") ? "kh-shared-${var.env_name}-nodejs-tg1" : "kh-${var.env_name}-nodejs-tg"
  port     = var.env_name == "mirror1" ? 80 : 3001 # Mirror1のALBが再作成されないように、3001ポートに戻ったらルール削除は
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc.id
  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = startswith(terraform.workspace, "prestage") && terraform.workspace != "prestage2" ? 3 : 5
    unhealthy_threshold = 2
    matcher             = 200
  }
}

resource "aws_alb_target_group_attachment" "tg-attachment_nodejs_1a" {
  depends_on       = [aws_instance.nodejs_a]
  count            = var.ec2.nodejs_instance_core_count
  target_group_arn = aws_alb_target_group.nodejs-tg1.arn
  target_id        = aws_instance.nodejs_a.0.id
  port             = count.index + 3001
}
resource "aws_route53_record" "alb1" {
  depends_on = [aws_alb.web-alb1]
  zone_id    = var.zone_id
  name       = var.env_name == "prod" ? "ws1.kamihimeproject.net" : "ws1-${var.env_name}-kh.nurika.be"
  type       = "CNAME"
  ttl        = 60
  records    = [aws_alb.web-alb1.dns_name]
}
