data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  # checkov:skip=CKV2_AWS_11: "VPC Flow Logs are disabled to minimize AWS costs for this interview demonstration project."
  # checkov:skip=CKV2_AWS_12: "Default security group is not used by EKS, so restricting it is low priority for this demo."
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                    = "wisecow-vpc"
    "kubernetes.io/cluster/wisecow-cluster" = "shared"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "wisecow-igw"
  }
}

resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130: "Public subnets require auto-assign public IP for EKS nodes to join the cluster without a NAT Gateway."
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name                                    = "wisecow-public-subnet-${count.index + 1}"
    "kubernetes.io/role/elb"                = "1"
    "kubernetes.io/cluster/wisecow-cluster" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "wisecow-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
