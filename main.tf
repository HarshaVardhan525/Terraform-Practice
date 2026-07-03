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

variable "server_port" {
    description = "Port used for http requests"
    type = number
    default = 8080
}
variable "ssh_port" {
    description = "Port used for http requests"
    type = number
    default = 8080
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

resource "aws_instance" "my_ec2" {
    ami = "ami-0d351f1b760a30161"
    instance_type = "t3.micro"
    key_name = "Mumbai-Key"
    subnet_id = aws_subnet.my_subnet.id
    vpc_security_group_ids = [aws_security_group.my_security_group.id]
  

    tags = {
        Name = "my_ec2"
    }

}

output "public_ip" {
    description = "The Public ip of the ec2 instance"
    value = aws_instance.my_ec2.public_ip
    
}
