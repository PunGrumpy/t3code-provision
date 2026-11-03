data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

data "openstack_networking_network_v2" "private" {
  name = var.network_name
}

resource "openstack_compute_keypair_v2" "this" {
  name       = var.name
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "openstack_networking_secgroup_v2" "this" {
  name = var.name
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  for_each          = toset(var.ssh_cidrs)
  security_group_id = openstack_networking_secgroup_v2.this.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
}

resource "openstack_blockstorage_volume_v3" "data" {
  name              = "${var.name}-data"
  size              = var.data_gb
  availability_zone = var.availability_zone
  volume_type       = var.volume_type
}

resource "openstack_networking_floatingip_v2" "this" {
  pool = var.floating_ip_pool
}

resource "openstack_networking_port_v2" "this" {
  count              = var.running ? 1 : 0
  name               = var.name
  network_id         = data.openstack_networking_network_v2.private.id
  security_group_ids = [openstack_networking_secgroup_v2.this.id]
}

resource "openstack_compute_instance_v2" "worker" {
  count             = var.running ? 1 : 0
  name              = var.name
  flavor_name       = var.flavor_name
  key_pair          = openstack_compute_keypair_v2.this.name
  availability_zone = var.availability_zone

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    # Nova exposes an attached Cinder volume under its id, truncated to the virtio serial length.
    data_device         = "/dev/disk/by-id/virtio-${substr(openstack_blockstorage_volume_v3.data.id, 0, 20)}"
    t3_channel          = var.t3_channel
    policy_organization = var.policy_organization
  })

  network {
    port = openstack_networking_port_v2.this[0].id
  }

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.root_gb
    boot_index            = 0
    delete_on_termination = true
  }

  # Attached at boot, so cloud-init sees the disk without racing a separate attach resource.
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.data.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = -1
    delete_on_termination = false
    disk_bus              = "virtio"
  }

  lifecycle {
    # A newer image upload must not silently rebuild a VM with agents running on it.
    ignore_changes = [block_device[0].uuid]
  }
}

resource "openstack_networking_floatingip_associate_v2" "this" {
  count       = var.running ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.this.address
  port_id     = openstack_networking_port_v2.this[0].id
}
