##                              ##
##Start of Building Services VPC##
#  Professional Services Shane Hale#
#### Create the Services VPC ####

resource "aws_vpc" "mainvpc" {
  cidr_block = "${var.MainVPCCIDR}"
  tags = {
    "Application" = "${var.MainStackName}"
    "Network" = "MGMT"
    "Name" = "${var.MainVPCName}"
  }
}
##################################
#### Create the Main VPC VGWs ####
##################################
resource "aws_vpn_gateway" "mainvpc" {
  vpc_id = "${aws_vpc.mainvpc.id}"

  tags {
    Name = "${var.MainVPCName}"
  }
}
#########################################################
#### Create the Services VPC Untrust & Trust subnets ####
#########################################################
resource "aws_subnet" "UntrustSubnet" {
  count      = "${var.count}"
  vpc_id     = "${aws_vpc.mainvpc.id}"
  cidr_block = "${element(var.UntrustCIDR_Block, count.index)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  #map_public_ip_on_launch = true
  tags {
        "Application" = "${var.MainStackName}"
        "Name" = "${join("", list(var.MainStackName, "AZ${count.index}-UntrustSubnet"))}"
  }
}

resource "aws_subnet" "TrustSubnet" {
  count      = "${var.count}"
  vpc_id     = "${aws_vpc.mainvpc.id}"
  cidr_block = "${element(var.TrustCIDR_Block, count.index)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  #map_public_ip_on_launch = true
  tags {
        "Application" = "${var.MainStackName}"
        "Name" = "${join("", list(var.MainStackName, "AZ${count.index}TrustSubnet"))}"
  }
}
###################################################
#### Name the default Transit VPC route tables ####
###################################################
resource "aws_default_route_table" "mainvpc" {
  default_route_table_id = "${aws_vpc.mainvpc.default_route_table_id}"

  tags {
    "Name" = "${join("", list(var.MainStackName, "RT"))}"
  }
}
#####################################
#### Create the Internet Gateway ####
#####################################
resource "aws_internet_gateway" "mainvpc" {
  vpc_id = "${aws_vpc.mainvpc.id}"

  tags {
    "Name" = "${join("", list(var.MainStackName, "IGW"))}"
  }
}
#############################################
### Create the Untrust Subnet route table ###
#############################################

resource "aws_route_table" "UntrustSubnet" {
  vpc_id = "${aws_vpc.mainvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.mainvpc.id}"
  }

  tags {
    "Name" = "${join("", list(var.MainStackName, "Untrust-RT"))}"
  }
}
#############################################
#### Create the Trust Subnet route table ####
#############################################
resource "aws_route_table" "TrustSubnet" {
  vpc_id = "${aws_vpc.mainvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.mainvpc.id}"
  }

  tags {
    "Name" = "${join("", list(var.MainStackName, "Trust-RT"))}"
  }
}
############################################
#### Create the Route Table association ####
############################################
resource "aws_route_table_association" "UntrustSubnet" {
  count          = "${var.count}"
  subnet_id      = "${element(aws_subnet.UntrustSubnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.UntrustSubnet.id}"
}

resource "aws_route_table_association" "TrustSubnet" {
  count          = "${var.count}"
  subnet_id      = "${element(aws_subnet.TrustSubnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.TrustSubnet.id}"
}
######################################
##### Create the Customer Gateway ####
######################################
resource "aws_customer_gateway" "mainvpc" {
  count      = "${var.count}"
  bgp_asn    = 64982
  ip_address = "${element(aws_eip.TrustElasticIP.*.public_ip, count.index)}"
  type       = "ipsec.1"

  tags {
    Name = "MainVPC-CGW-${count.index}"
  }
}
##################################################
#### Create Management Network Security Group ####
##################################################
resource "aws_security_group" "sgWideOpen" {
  name        = "sgWideOpen"
  description = "Wide open security group"
  vpc_id = "${aws_vpc.mainvpc.id}"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = "0"
    to_port         = "0"
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    "Name" = "SgWideOpen"
  }
}
##########################################
#### Create an S3 endpoint in the VPC ####
########################################## 
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = "${aws_vpc.mainvpc.id}"
  service_name = "com.amazonaws.${var.aws_region}.s3"
}
 
resource "aws_vpc_endpoint_route_table_association" "rtmainvpcs3" {
  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${aws_route_table.UntrustSubnet.id}"
}
#########################################
#### Create the Elastic IP Addresses ####
#########################################
resource "aws_eip" "TrustElasticIP" {
  count = "${var.count}"
  vpc   = true
  depends_on = ["aws_vpc.mainvpc", "aws_internet_gateway.mainvpc"]
}

resource "aws_eip" "ManagementElasticIP" {
  count = "${var.count}"
  vpc   = true
  depends_on = ["aws_vpc.mainvpc", "aws_internet_gateway.mainvpc"]
}