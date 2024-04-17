provider "aws" {
    region = "ap-south-1"
}

resource "aws_instance" "dev-instance" {
    ami                    = "ami-007020fd9c84e18c7"
    instance_type          = "t2.micro"
    key_name               = "prod"
    subnet_id              = aws_subnet.ubs-subnet.id
    vpc_security_group_ids = [aws_security_group.ubs-sg.id]
    for_each               = toset(["jenkins-master", "jenkins-slave", "ansible"])
    
    tags = {
        Name = "${each.key}"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo apt update",
            "sudo apt install -y software-properties-common",
            "sudo add-apt-repository --yes --update ppa:ansible/ansible",
            "sudo apt install -y ansible"
        ]

        connection {
            type        = "ssh"
            user        = "ubuntu" 
            private_key = file("C:/Users/lenovo/Desktop/mywork/New folder/banking/jenkinssetup/prod.pem")
            host        = self.public_ip
            timeout     = "10m"
        }
    }
}



# Create a new VPC
resource "aws_vpc" "ubs-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "ubs-vpc"
  }
}

# Create a subnet within the VPC
resource "aws_subnet" "ubs-subnet" {
  vpc_id            = aws_vpc.ubs-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "ubs-subnet"
  }
}

# Create an internet gateway for the VPC
resource "aws_internet_gateway" "ubs-igw" {
  vpc_id = aws_vpc.ubs-vpc.id
  tags = {
    Name = "ubs-igw"
  }
}

# Create a route table for the VPC
resource "aws_route_table" "ubs-routingtable" {
  vpc_id = aws_vpc.ubs-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ubs-igw.id
  }
  tags = {
    Name = "ubs-routingtable"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "ubs-routingtablea" {
  subnet_id      = aws_subnet.ubs-subnet.id
  route_table_id = aws_route_table.ubs-routingtable.id
}

# Create a security group that allows SSH inbound traffic
resource "aws_security_group" "ubs-sg" {
  name        = "ubs-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.ubs-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Jenkins port"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ubs-sg"
  }
}

# Output public IPs of instances for Ansible inventory
output "ansible_inventory" {
    value = {
        jenkins-master = aws_instance.dev-instance["jenkins-master"].public_ip
        jenkins-slave  = aws_instance.dev-instance["jenkins-slave"].public_ip
    }
}