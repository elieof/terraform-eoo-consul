variable "lb_name" {
  type = string
}

variable "install_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "sg_id" {
  type = string
}

variable "env" {
  type    = string
  default = "dev"
}

resource "aws_s3_bucket" "lb_logs" {
  bucket        = format("eoo-%s-logs", var.lb_name)
  force_destroy = true
  tags = {
    Name         = format("eoo-%s-logs", var.lb_name)
    env          = var.env
    install_name = var.install_name
  }
}

data "aws_subnet_ids" "lb_subnet" {
  vpc_id = var.vpc_id
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "s3_lb_write" {
  policy_id = "s3_lb_write"

  statement {
    sid = "Allow ALB to put AccessLogs"

    actions = [
      "s3:PutObject"
    ]
    resources = [
      format("%s/*", aws_s3_bucket.lb_logs.arn)
    ]

    principals {
      identifiers = [
        data.aws_elb_service_account.main.arn
      ]
      type = "AWS"
    }
    effect = "Allow"
  }
}

resource "aws_s3_bucket_policy" "s3_policy" {
  bucket = aws_s3_bucket.lb_logs.id
  policy = data.aws_iam_policy_document.s3_lb_write.json
}

resource "aws_lb" "lb_instance" {
  name               = var.lb_name
  internal           = false
  load_balancer_type = "application"
  idle_timeout       = 60
  security_groups    = [var.sg_id]
  subnets            = data.aws_subnet_ids.lb_subnet.ids
  
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.lb_logs.bucket
    prefix  = "instance"
    enabled = true
  }

  tags = {
    Name         = var.lb_name
    env          = var.env
    install_name = var.install_name
  }
  
  depends_on = [
    aws_s3_bucket_policy.s3_policy
  ]
}

resource "aws_lb_target_group" "lb_tg" {
  name     = format("%s-tg", var.lb_name)
  port     = 8500
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path    = "/"
    port    = "8500"
    matcher = "200,301"
  }

  depends_on = [
    aws_lb.lb_instance
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name         = var.lb_name
    env          = var.env
    install_name = var.install_name
  }
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb_instance.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
}

output "dns" {
  value = aws_lb.lb_instance.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.lb_tg.arn
}
