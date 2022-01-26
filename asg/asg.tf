variable "asg_name" {
  type = string
}
variable "install_name" {
  type = string
}
variable "asg_sg_id" {
  type = string
}
variable "asg_target_group_arn" {
  type = string
}
variable "bucket_repo_app" {
  type    = string
  default = "elieof-eoo/artifacts/ansible"
}
variable "asg_max" {
  type    = number
  default = 1
}
variable "asg_min" {
  type    = number
  default = 1
}
variable "asg_des" {
  type    = number
  default = 1
}
variable "asg_def_cooldown" {
  type    = number
  default = 3000
}
variable "region" {
  type    = string
  default = "eu-west-1"
}
variable "env" {
  type    = string
  default = "dev"
}
variable "aws_account" {
  type    = string
  default = "247452219447"
}

locals {
  name = format("%s", var.asg_name)
}

resource "aws_cloudwatch_log_group" "asg" {
  name              = format("%s", local.name)
  retention_in_days = 30

  tags = {
    Name         = format("%s-log-group", local.name)
    env          = var.env
    install_name = var.install_name
  }
}

data "template_file" "user_data" {
  template = file("asg/templates/user_data.sh.tpl")
}

resource "aws_launch_template" "consul_launch_template" {
  name_prefix            = format("%s", local.name)
  description            = "Launch template for consul"
  image_id               = "ami-0ffea00000f287d30"
  instance_type          = "t2.micro"
  key_name               = "ec2BlAccessKey"
  vpc_security_group_ids = [var.asg_sg_id]
  user_data              = base64encode(data.template_file.user_data.rendered)

  iam_instance_profile {
    name = aws_iam_instance_profile.consul_profile.name
  }

  monitoring {
    enabled = true
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name         = format("%s-ec2", local.name)
      env          = var.env
      install_name = var.install_name
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name         = format("%s-ec2", local.name)
      env          = var.env
      install_name = var.install_name
    }
  }
}

resource "aws_autoscaling_group" "consul_asg" {
  name_prefix        = format("%s-", local.name)
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  max_size           = var.asg_max
  min_size           = var.asg_min
  desired_capacity   = var.asg_des

  health_check_type = "ELB"

  default_cooldown = var.asg_def_cooldown

  target_group_arns = [var.asg_target_group_arn]

  launch_template {
    id      = aws_launch_template.consul_launch_template.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    propagate_at_launch = false
    value               = format("%s-ec2", local.name)
  }

  tag {
    key                 = "env"
    propagate_at_launch = false
    value               = var.env
  }
}


resource "aws_iam_instance_profile" "consul_profile" {
  name_prefix = format("%s-", local.name)
  role        = aws_iam_role.consul_role.name
}

resource "aws_iam_role" "consul_role" {
  name_prefix        = format("%s-", local.name)
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_doc.json

  tags = {
    Name         = format("%s-iam-role", local.name)
    env          = var.env
    install_name = var.install_name
  }
}

data "aws_iam_policy_document" "assume_role_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role_policy" "consul_policy" {
  role   = aws_iam_role.consul_role.id
  policy = data.aws_iam_policy_document.consul_policy_document.json
}

data "aws_iam_policy_document" "consul_policy_document" {
  statement {
    actions   = ["s3:GetObject"]
    resources = [format("arn:aws:s3:::%s/*", var.bucket_repo_app)]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [format("arn:aws:s3:::%s", var.bucket_repo_app)]
  }

  statement {
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "autoscaling:DescribeAutoScalingGroups",
      "elasticloadbalancing:DescribeTargetGroups",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:SetAlarmState",
      "cloudwatch:DescribeAlarms",
    ]
    resources = ["*"]
  }

  statement {
    actions = ["sns:Publish"]
    resources = [
    format("arn:aws:sns:%s:%s:%s", var.region, var.aws_account, "monitoring-eoo")]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [aws_cloudwatch_log_group.asg.arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = [format("arn:aws:s3:::elieof-eoo/backups/%s*", var.env)]
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = [format("arn:aws:s3:::elieof-eoo/backups/%s/%s*", var.env, var.install_name)]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [format("arn:aws:s3:::elieof-eoo/backups/%s", var.env)]
  }
}

resource "aws_cloudwatch_metric_alarm" "ASGLooping" {
  alarm_name          = format("%s.AsgLooping", local.name)
  alarm_description   = format("CONSUL_%s_%s|AsgLooping|Consul ASG Looping alarm", upper(var.install_name), upper(var.env))
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupTerminatingInstances"
  namespace           = "AWS/AutoScaling"
  statistic           = "Sum"
  period              = 900
  threshold           = 3

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.consul_asg.name}"
  }
  alarm_actions             = [format("arn:aws:sns:eu-west-1:%s:monitoring-eoo", var.aws_account)]
  ok_actions                = [format("arn:aws:sns:eu-west-1:%s:monitoring-eoo", var.aws_account)]
  insufficient_data_actions = [format("arn:aws:sns:eu-west-1:%s:monitoring-eoo", var.aws_account)]

}
