provider "aws" {
    region = "ap-south-1"
}    

resource "aws_instance" "my_ec2" {
    ami = "ami-0d351f1b760a30161"
    instance_type = "t3.micro"
    subnet_id = "subnet-07474054233d0abc5"
    tags = {
        Name = "testvm"
    }
}