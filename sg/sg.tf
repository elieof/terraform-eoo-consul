variable "sg_name" {
  type = string
}

variable "install_name" {
  type = string
}

variable "sg_description" {
  type = string
  default = ""
}

variable "env" {
  type = string
  default = "dev"
}
# variable "sg_ids" {
#   type = list(string)
#   default = []
# }

variable "sg_ingress_elements" {
  type = list(object({
    port = number,
    protocol = string,
    desc = string,
    sg_ids = list(string),
    self = bool,
  }))
  default = [
    {
      port = 80
      protocol = "TCP"
      desc = "Allow HTTP"
      sg_ids = []
      self = true
    },
    {
      port = 443,
      protocol = "TCP"
      desc = "Allow HTTPS"
      sg_ids = []
      self = true
    },
    {
      port = 22,
      protocol = "TCP"
      desc = "Allow SSH"
      sg_ids = []
      self = false
    }
  ]
}

variable "sg_egress_elements" {
  type = list(object({
    port = number,
    protocol = string,
    sg_ids = list(string),
    desc = string
    self = bool,
  }))
  default = [
    {
      port = 0
      protocol = "-1"
      desc = "Allow all"
      sg_ids = []
      self = true
    }
  ]
}

variable "sg_ingress_cidr_blocks" {
  type = list(string)
  default = [
    "86.247.199.218/32"
  ]
}

variable "sg_egress_cidr_blocks" {
  type = list(string)
  default = [
    "0.0.0.0/0"
  ]
}

resource "aws_security_group" "sg_instance" {
  name = var.sg_name
  description = var.sg_description != "" ? var.sg_description : format("security group for %s", var.sg_name)
  lifecycle {
    create_before_destroy = true
  }
  # dynamic "ingress" {
  #   iterator = element
  #   for_each = var.sg_ids
  #   content {
  #     from_port = 80
  #     protocol = "TCP"
  #     to_port = 80
  #     description = format("Allow incoming HTTP from security_group %s", element.value)
  #     security_groups = var.sg_ids
  #     self = true
  #   }
  # }

  dynamic "ingress" {
    iterator = element
    for_each = var.sg_ingress_elements
    content {
      from_port = element.value.port
      protocol = element.value.protocol
      to_port = element.value.port
      description = "${element.value.desc} on incoming"
      cidr_blocks = var.sg_ingress_cidr_blocks
      security_groups = element.value.sg_ids
      self = element.value.self
    }
  }

  dynamic "egress" {
    iterator = element
    for_each = var.sg_egress_elements
    content {
      from_port = element.value.port
      protocol = element.value.protocol
      to_port = element.value.port
      description = "${element.value.desc} on outgoing"
      cidr_blocks = var.sg_egress_cidr_blocks
      security_groups = element.value.sg_ids
      self = element.value.self
    }
  }

  tags = {
    Name = var.sg_name
    env          = var.env
    install_name = var.install_name
  }
}

output "id" {
  value = aws_security_group.sg_instance.id
}

output "name" {
  value = aws_security_group.sg_instance.name
}

output "vpc_id" {
  value = aws_security_group.sg_instance.vpc_id
}
