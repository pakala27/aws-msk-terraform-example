provider "aws" {
  region = "eu-central-1"
}

#Variable Definition
variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     =  "192.168.0.0/16"
}
variable "sn1_cidr" {
  description = "subnet 1 CIDR block"
  default     =  "192.168.1.0/24"
}
variable "sn2_cidr" {
  description = "subnet 2 CIDR block"
  default     =  "192.168.2.0/24"
}
variable "sn3_cidr" {
  description = "subnet 3 CIDR block"
  default     =  "192.168.3.0/24"
}
variable "kafka_version" {
  description = "Kafka Version"
  default     =  "2.6.2"
}

#VPC Creation
resource "aws_vpc" "vpc-msk-01" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "vpc-msk-01"
  }
}

# Subnets creation
resource "aws_subnet" "sn-msk-01" {
  vpc_id            = aws_vpc.vpc-msk-01.id
  cidr_block        = var.sn1_cidr
  availability_zone = "eu-central-1a"

  tags = {
    Name = "sn-msk-01"
  }
}

resource "aws_subnet" "sn-msk-02" {
  vpc_id            = aws_vpc.vpc-msk-01.id
  cidr_block        = var.sn2_cidr
  availability_zone = "eu-central-1b"

  tags = {
    Name = "sn-msk-02"
  }
}

resource "aws_subnet" "sn-msk-03" {
  vpc_id            = aws_vpc.vpc-msk-01.id
  cidr_block        = var.sn3_cidr
  availability_zone = "eu-central-1c"

  tags = {
    Name = "sn-msk-03"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "igw-msk-01" {
  vpc_id = aws_vpc.vpc-msk-01.id

  tags = {
    Name = "igw-msk-01"
  }
}

#Route Table
resource "aws_route_table" "rtb-msk-01" {
  vpc_id = aws_vpc.vpc-msk-01.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw-msk-01.id
  }
  route {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.igw-msk-01.id
  }

  tags = {
    Name = "rtb-msk-01"
  }
}

#Route table association for subnet 1
resource "aws_route_table_association" "rtb-msk-assc-01" {
  subnet_id      = aws_subnet.sn-msk-01.id
  route_table_id = aws_route_table.rtb-msk-01.id
}

#Security Group
resource "aws_security_group" "sgmsk01" {
  name        = "allow_tcp"
  description = "allow all ports within VPC and allow SSH from anywhere"
  vpc_id      = aws_vpc.vpc-msk-01.id

  ingress {
      description      = "All TCP ports allowed inside VPC"
      from_port        = 0
      to_port          = 65535
      protocol         = "tcp"
      cidr_blocks      = [aws_vpc.vpc-msk-01.cidr_block]
    }
  ingress {
      description      = "SSH access to DevOps EC2 Instance"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
      description      = "Promethes port access to DevOps EC2 Instance"
      from_port        = 9090
      to_port          = 9090
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sq-msk-01"
  }
}

#Create network interface and assign a private IP from subnet 1 for DevOps EC2 instances
resource "aws_network_interface" "ni-devops-01" {
  subnet_id       = aws_subnet.sn-msk-01.id
  private_ips     = ["192.168.1.10"]
  security_groups = [aws_security_group.sgmsk01.id]
}

#Assign Elastic IP to the network interface created on previous step
resource "aws_eip" "eip-devops-01" {
  vpc                       = true
  network_interface         = aws_network_interface.ni-devops-01.id
  associate_with_private_ip = "192.168.1.10"
  depends_on                = [aws_internet_gateway.igw-msk-01]
  tags = {
    Name = "eip-devops-01"
  }
}


#Create DevOps EC2 Instance
resource "aws_instance" "devops" {
  ami               = "ami-06ec8443c2a35b0ba"
  instance_type     = "t2.micro"
  availability_zone = "eu-central-1a"
  key_name          = "aws-msk"
  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.ni-devops-01.id
  }
  user_data = <<EOF
                sudo yum install -y java-11-openjdk-devel
                sudo yum install -y wget
                wget https://downloads.apache.org/kafka/2.8.0/kafka_2.13-2.8.0.tgz
                tar -xf kafka_2.13-2.8.0.tgz
                export PATH=$PATH:/home/ec2-user/kafka_2.13-2.8.0/bin
                echo 'export PATH=$PATH:/home/ec2-user/kafka_2.13-2.8.0/bin' >> /home/ec2-user/.bashrc
                wget https://github.com/aws/aws-msk-iam-auth/releases/download/v1.1.1/aws-msk-iam-auth-1.1.1-all.jar
                export CLASSPATH=/home/ec2-user/aws-msk-iam-auth-1.1.1-all.jar
                EOF
  tags = {
    Name = "devops"
  }
}


#Create msk 
resource "aws_msk_cluster" "msk-cluster-01" {
  cluster_name           = "msk-cluster-01"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = 3
  enhanced_monitoring    = "PER_TOPIC_PER_PARTITION"
  client_authentication {
    sasl {
      iam = true
    }
  }
  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  broker_node_group_info {
    instance_type         = "kafka.m5.large"
    ebs_volume_size       = 15
    client_subnets = [
      aws_subnet.sn-msk-01.id,
      aws_subnet.sn-msk-02.id,
      aws_subnet.sn-msk-03.id,
    ]
    security_groups = [aws_security_group.sgmsk01.id]
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  tags = {
    name = "msk-cluster-01"
  }
}

#Output
output "devops_public_ip" {
  value = aws_eip.eip-devops-01.public_ip
}
output "aws_msk_cluster_ARN" {
  value = aws_msk_cluster.msk-cluster-01.arn
}
output "aws_msk_cluster_bootstrap_servers" {
  value = aws_msk_cluster.msk-cluster-01.bootstrap_brokers_sasl_iam
}
output "aws_msk_cluster_zookeeper_connect" {
  value = aws_msk_cluster.msk-cluster-01.zookeeper_connect_string
}



