locals {
  availability_zone = coalesce(var.availability_zone, "${var.region}a")
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "aws_subnet" "this" {
  availability_zone = local.availability_zone
  default_for_az    = true
}

resource "aws_key_pair" "this" {
  key_name   = var.name
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_security_group" "this" {
  name   = var.name
  vpc_id = data.aws_subnet.this.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each          = toset(var.ssh_cidrs)
  security_group_id = aws_security_group.this.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_ebs_volume" "data" {
  availability_zone = local.availability_zone
  size              = var.data_gb
  type              = "gp3"
  tags              = { Name = "${var.name}-data" }
}

module "bootstrap" {
  source = "../../modules/bootstrap"
  # Nitro exposes EBS as NVMe with the volume id, minus its hyphen, as the serial.
  data_device         = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(aws_ebs_volume.data.id, "-", "")}"
  t3_channel          = var.t3_channel
  policy_organization = var.policy_organization
  ssh_public_key      = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "worker" {
  count                       = var.running ? 1 : 0
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.this.id
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  user_data                   = module.bootstrap.user_data
  user_data_replace_on_change = true
  tags                        = { Name = var.name }

  root_block_device {
    volume_size = var.root_gb
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "required"
  }

  lifecycle {
    # A newer AMI must not silently rebuild an instance with agents running on it.
    ignore_changes = [ami]
  }
}

resource "aws_volume_attachment" "data" {
  count                          = var.running ? 1 : 0
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.data.id
  instance_id                    = aws_instance.worker[0].id
  stop_instance_before_detaching = true
}
