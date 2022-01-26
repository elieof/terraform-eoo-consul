provider "aws" {}

variable "env" {
  type    = string
  default = "dev"
}
variable "install_name" {
  type    = string
  default = "eoo-consul"
}

module "consul_lb_sg" {
  source  = "./sg"
  sg_name = format("%s-lb-sg", var.install_name)
  install_name = var.install_name
  sg_ingress_elements = [
    {
      port     = 80
      protocol = "TCP"
      desc     = "Allow HTTP"
      sg_ids   = []
      self     = false
    },
    {
      port     = 443,
      protocol = "TCP"
      desc     = "Allow HTTPS"
      sg_ids   = []
      self     = false
    }
  ]
}

module "consul_asg_sg" {
  source  = "./sg"
  sg_name = format("%s-asg-sg", var.install_name)
  install_name = var.install_name
  depends_on   = [module.consul_lb_sg]
  sg_ingress_elements = [
    {
      port     = 8300
      protocol = "TCP"
      desc     = "Allow HTTP"
      sg_ids   = []
      self     = true
    },
    {
      port     = 8301
      protocol = "TCP"
      desc     = "Allow HTTP"
      sg_ids   = []
      self     = true
    },
    {
      port     = 8500
      protocol = "TCP"
      desc     = "Allow HTTP"
      sg_ids   = [module.consul_lb_sg.id]
      self     = false
    },
    {
      port     = 22,
      protocol = "TCP"
      desc     = "Allow SSH"
      sg_ids   = []
      self     = false
    }
  ]
}

module "consul_lb" {
  source       = "./alb"
  lb_name      = format("%s-alb", var.install_name)
  install_name = var.install_name
  sg_id        = module.consul_lb_sg.id
  vpc_id       = module.consul_lb_sg.vpc_id
  depends_on   = [module.consul_lb_sg]
}

module "consul_asg" {
  source               = "./asg"
  asg_name             = format("%s-asg", var.install_name)
  install_name         = var.install_name
  asg_sg_id            = module.consul_asg_sg.id
  asg_target_group_arn = module.consul_lb.target_group_arn
  depends_on           = [module.consul_lb, module.consul_asg_sg]
}

output "consul_lb_dns" {
  value = module.consul_lb.dns
}

# output "consul_ec2_public_ip" {
#   value = module.consul_ec2.public_ip
# }

# output "consul_ec2_private_ip" {
#   value = module.consul_ec2.private_ip
# }
