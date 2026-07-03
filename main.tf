terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.53.0"
    }
  }
}



provider "aws" {
    region = "ap-south-1"
}    

resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "my_vpc"
    }
}

resource "aws_subnet" "my_subnet" {
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "my_subnet"
    }
}
resource "aws_subnet" "my_subnet2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "my_subnet2"
  }
}

resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.my_vpc.id
    tags = {
        Name = "my_igw"
    }
}

resource "aws_route_table" "my_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_igw.id
    }
    tags = {
        Name = "my_route_table"
    }   
}

resource "aws_route_table_association" "my_route_table_association" {
    subnet_id = aws_subnet.my_subnet.id
    route_table_id = aws_route_table.my_route_table.id
}
resource "aws_route_table_association" "my_route_table_association2" {
  subnet_id      = aws_subnet.my_subnet2.id
  route_table_id = aws_route_table.my_route_table.id
}

variable "server_port" {
    description = "Port used for http requests"
    type = number
    default = 80
}
variable "ssh_port" {
    description = "Port used for http requests"
    type = number
    default = 22
}

resource "aws_security_group" "my_security_group" {
    name = "my_security_group"
    vpc_id = aws_vpc.my_vpc.id
    ingress {
        from_port = var.ssh_port
        to_port = var.ssh_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "my_security_group"
    }
}

resource "aws_launch_template" "my_lt" {
  name_prefix   = "my-launch-template-"
  image_id      = "ami-0d351f1b760a30161"
  instance_type = "t3.micro"
  key_name      = "Mumbai-Key"

  vpc_security_group_ids = [
    aws_security_group.my_security_group.id
  ]

user_data = base64encode(<<-EOF
#!/bin/bash
dnf update -y
dnf install -y nginx

systemctl enable nginx
systemctl start nginx

echo "<h1>Welcome to my EC2 instance</h1>" > /usr/share/nginx/html/index.html
EOF
)
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "my_ec2"
    }
  }
}



resource "aws_autoscaling_group" "my_asg" {
 launch_template {
  id      = aws_launch_template.my_lt.id
  version = "$Latest"
}

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  vpc_zone_identifier = [
    aws_subnet.my_subnet.id,
    aws_subnet.my_subnet2.id
  ]

  target_group_arns = [aws_lb_target_group.my_target_group.arn]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "my_asg"
    propagate_at_launch = true
  }
}

resource "aws_lb" "my_lb" {
    name               = "my-asg"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb.id]
    subnets = [
        aws_subnet.my_subnet.id,
        aws_subnet.my_subnet2.id
        ]

    tags = {
        Name = "my_lb"
    }
}
resource "aws_lb_listener" "http_listener" {
    load_balancer_arn = aws_lb.my_lb.arn
    port              = var.server_port
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.my_target_group.arn
    }
}
resource "aws_security_group" "alb" {
  name        = "alb-security-group"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}

resource "aws_lb_target_group" "my_target_group" {
    name     = "my-target-group"
    port     = var.server_port
    protocol = "HTTP"
    vpc_id = aws_vpc.my_vpc.id

    health_check {
        path                = "/"
        protocol            = "HTTP"
        interval            = 15
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200"
    }

    tags = {
        Name = "my_target_group"
    }
}


output "alb_dns_name" {
    description = "The DNS name of the Application Load Balancer"
    value = aws_lb.my_lb.dns_name
}
