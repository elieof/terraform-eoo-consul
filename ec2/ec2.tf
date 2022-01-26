variable "web_server_name" {
  type = string
}

variable "sg_names" {
  type = list(string)
}

resource "aws_instance" "web_server" {
  ami = "ami-096f43ef67d75e998"
  instance_type = "t2.micro"
  security_groups = var.sg_names
  user_data = file("./ec2/server-script.sh")
  key_name = "ec2BlAccessKey"
  tags = {
    Name = var.web_server_name
  }
}

output "public_ip" {
  value = aws_instance.web_server.public_ip
}

output "private_ip" {
  value = aws_instance.web_server.private_ip
}

output "id" {
  value = aws_instance.web_server.id
}
