#Create VPC in us-east-1
resource "aws_vpc" "vpc_master" {
    provider = aws.region-master
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "master-vpc-jenkins"
    }
}

#Create VPC in us-west-2
resource "aws_vpc" "vpc_worker" {
    provider = aws.region-worker
    cidr_block = "192.168.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "worker-vpc-jenkins"
    }
}

#Create IGW in us-east-1
resource "aws_internet_gateway" "igw" {
    provider = aws.region-master
    vpc_id = aws_vpc.vpc_master.id
}

#Create IGW in us-west-2
resource "aws_internet_gateway" "igw-west" { 
    provider = aws.region-worker
    vpc_id = aws_vpc.vpc_worker.id
}

#Get all available AZ's in VPC for master region thanks to the data method 
data "aws_availability_zones" "azs" {
    provider = aws.region-master
    state = "available"
}

#Create subnet 1 in us-east-1
resource "aws_subnet" "subnet_1" {
    provider = aws.region-master
    availability_zone = element(data.aws_availability_zones.azs.names, 0)
    vpc_id = aws_vpc.vpc_master.id
    cidr_block = "10.0.1.0/24"
}

#Create subnet 2 in us-east-1
resource "aws_subnet" "subnet_2" {
    provider = aws.region-master
    availability_zone = element(data.aws_availability_zones.azs.names, 1)
    vpc_id = aws_vpc.vpc_master.id
    cidr_block = "10.0.2.0/24"
}

#Create subnet 1 in us-west-2
resource "aws_subnet" "subnet_1_west"{
    provider = aws.region-worker
    vpc_id = aws_vpc.vpc_worker.id
    cidr_block = "192.168.1.0/24"
}






### VPC Peering & Routing

##Communication des VPCs entre eux
#Initiate Peering connection request from us-east-1
resource "aws_vpc_peering_connection" "useast1-uswest2" {
    provider = aws.region-master
    vpc_id = aws_vpc.vpc_master.id
    peer_region = var.region-worker
    peer_vpc_id = aws_vpc.vpc_worker.id
}

#Accept peering request in us-west-2 from us-east-1
resource "aws_vpc_peering_connection_accepter" "accept_peering" {
    provider = aws.region-worker
    vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
    auto_accept = true
}

##Communication des sous-réseaux entre eux et je met à jour la table de routage dans le deuxième resource
#Create route table in us-east-1
resource "aws_route_table" "internet_route" {
    provider = aws.region-master
    vpc_id = aws_vpc.vpc_master.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    route {
        cidr_block = "192.168.1.0/24"
        vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
    }
    lifecycle {
        ignore_changes = all
    }
    tags = {
        Name = "Master-Region-RT"
    }
}

#Overwrite default route table of VPC(Master) with our route table entries (we are not creating a resource, we are modifying it)
resource "aws_main_route_table_association" "set-master-default-rt-assoc" {
    provider = aws.region-master
    vpc_id =  aws_vpc.vpc_master.id
    route_table_id = aws_route_table.internet_route.id
}

#Create route table in us-west-2
resource "aws_route_table" "internet_route_west" {
    provider = aws.region-worker
    vpc_id = aws_vpc.vpc_worker.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw-west.id
    }
    route {
        cidr_block = "10.0.1.0/24"
        vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
    }
    lifecycle {
        ignore_changes = all
    }
    tags = {
        Name = "Worker-Region-RT"
    }
}

#Overwrite default route table of VPC(Worker) with our route table entries (we are not creating a resource, we are modifying it)
resource "aws_main_route_table_association" "set-worker-default-rt-assoc" {
  provider = aws.region-worker
  vpc_id         = aws_vpc.vpc_worker.id
  route_table_id = aws_route_table.internet_route_west.id
}