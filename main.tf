provider "aws" {
  region = "${var.location}"
}

# Get subnet data
data "aws_subnet" "subnet" {
  cidr_block = "${var.subnet}"
}

# Get admin secrurity group
data "aws_security_group" "sgs" {
  count = "${length(var.security_group_names)}"
  tags = {
    Name = "${element(var.security_group_names, count.index)}"
  }
}

# Get Windows server 2016 image id
data "aws_ami" "windows_server" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Base-*"]
  }
}



# Create repository instance
module "instance_ec2" {
  source = "github.com/terraform-aws-modules/terraform-aws-ec2-instance"

  name                        = "${var.instance_name}"
  instance_count              = 1
  ami                         = "${data.aws_ami.windows_server.id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.key_name}"
  monitoring                  = true
  vpc_security_group_ids      = ["${data.aws_security_group.sgs.*.id}"]
  subnet_id                   = "${data.aws_subnet.subnet.id}"
  user_data                   = "${var.user_data}"
  private_ip                  = "${var.ip}"
  root_block_device           = [{
                                  delete_on_termination = true,
                                  volume_size = "${var.os_size}"
                                }]

  tags                        = "${var.tags}"
}
resource "aws_volume_attachment" "instance_ec2" {
  count         = "${var.data_disk_size != 0 ? 1 : 0}"
  device_name   = "/dev/sdb"
  volume_id     = "${element(aws_ebs_volume.instance_ec2.*.id, count.index)}"
  instance_id   = "${element(module.instance_ec2.id, count.index)}"
  force_detach  = true
}
resource "aws_ebs_volume" "instance_ec2" {
  count             = "${var.data_disk_size != 0 ? 1 : 0}"
  availability_zone = "${module.instance_ec2.availability_zone[0]}"
  size              = "${var.data_disk_size}"
}