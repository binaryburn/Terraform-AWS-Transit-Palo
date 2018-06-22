# Deploy Transit #1 Bootstraps
#
# bucketname needs to be replaced with S3 bucket for bootstrapping.
# Create a new Palo Alto Networks VM-series Firewall with
# bootstrapping from a S3 bucket
#### Create IAM roles to launch firewall bootstrapping ####

resource "aws_iam_role" "FirewallBootstrapRoleServices" {
  name = "FirewallBootstrapRoleServices1"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
      "Service": "ec2.amazonaws.com"
    },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "FirewallBootstrapRolePolicyServices" {
  name = "FirewallBootstrapRolePolicyServices1"
  role = "${aws_iam_role.FirewallBootstrapRoleServices.id}"

  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::bucketname"
    },
    {
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::bucketname/*"
    }
  ]
}
EOF
}
resource "aws_iam_instance_profile" "FirewallBootstrapInstanceProfileServices" {
  name  = "FirewallBootstrapInstanceProfileServices1"
  role = "${aws_iam_role.FirewallBootstrapRoleServices.name}"
  path = "/"
}

#### Create Network Interfaces ####

resource "aws_network_interface" "FWManagementNetworkInterface" {
  count      = "${var.count}"
  subnet_id       = "${element(aws_subnet.UntrustSubnet.*.id, count.index)}"
  security_groups = ["${aws_security_group.sgWideOpen.id}"]
  source_dest_check = false
  #private_ips_count = 1
  #private_ips = ["10.0.0.99"]

  tags {
    "Name" = "${join("", list(var.MainStackName, "FW-AZ-${count.index+1}-Mgmt"))}"
  }
}

resource "aws_network_interface" "FWPublicNetworkInterface" {
  count      = "${var.count}"
  subnet_id       = "${element(aws_subnet.UntrustSubnet.*.id, count.index)}"
  #subnet_id       = "${aws_subnet.UntrustSubnet.id}"
  security_groups = ["${aws_security_group.sgWideOpen.id}"]
  source_dest_check = false
  #private_ips_count = 1
  #private_ips = ["10.0.0.100"]

  tags {
    "Name" = "${join("", list(var.MainStackName, "FW-AZ-${count.index+1}-Eth1-1"))}"
  }

}

resource "aws_network_interface" "FWPrivateNetworkInterface" {
  count      = "${var.count}"
  subnet_id       = "${element(aws_subnet.TrustSubnet.*.id, count.index)}"
  security_groups = ["${aws_security_group.sgWideOpen.id}"]
  source_dest_check = false
  #private_ips_count = 1
  #private_ips = ["10.0.1.11"]

  tags {
    "Name" = "${join("", list(var.MainStackName, "FW-AZ-${count.index+1}-Eth1-2"))}"
  }
}
#### Create the Elastic IP Association ####

resource "aws_eip_association" "FWEIPManagementAssociation" {
  count = "${var.count}"
  network_interface_id   = "${element(aws_network_interface.FWManagementNetworkInterface.*.id, count.index)}"
  allocation_id = "${element(aws_eip.ManagementElasticIP.*.id, count.index)}"
}

resource "aws_eip_association" "FWTrustAssociation" {
  count = "${var.count}"
  network_interface_id   = "${element(aws_network_interface.FWPrivateNetworkInterface.*.id, count.index)}"
  allocation_id = "${element(aws_eip.TrustElasticIP.*.id, count.index)}"
}

#### Create the Firewalls ####

resource "aws_instance" "FWInstance" {
  count = "${var.count}"
  disable_api_termination = false
  iam_instance_profile = "${aws_iam_instance_profile.FirewallBootstrapInstanceProfileServices.name}"
  instance_initiated_shutdown_behavior = "stop"
  #availability_zone = "${var.azs[count.index]}"
  ebs_optimized = true
  ami = "${var.BYOLPANFWRegionMap809[var.aws_region]}"
  instance_type = "m4.xlarge"

  ebs_block_device {
    device_name = "/dev/xvda"
    volume_type = "gp2"
    delete_on_termination = true
    volume_size = 60
  }

  key_name = "${var.serverkey}"
  monitoring = false

  network_interface {
    device_index = 0
    network_interface_id = "${element(aws_network_interface.FWManagementNetworkInterface.*.id, count.index)}"
  }

  network_interface {
    device_index = 1
    network_interface_id = "${element(aws_network_interface.FWPublicNetworkInterface.*.id, count.index)}"
  }

  network_interface {
    device_index = 2
    network_interface_id = "${element(aws_network_interface.FWPrivateNetworkInterface.*.id, count.index)}"
  }
###This will be the place for Bootstrapping the Firewall one config per AZ. Terraform does not like list interpolation and variables currently##
   #user_data = "${base64encode(join("", list("vmseries-bootstrap-aws-s3bucket=", var.MasterS3Bucket)))}"
   user_data = "vmseries-bootstrap-aws-s3bucket=bucketname"
  tags {
    "Name" = "${join("", list(var.MainStackName, "FW-AZ-${count.index +1}"))}"
  }

  lifecycle {
        ignore_changes = [ "ebs_block_device" ]
  }
}
