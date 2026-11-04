resource "hcloud_ssh_key" "this" {
  name       = var.name
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_firewall" "this" {
  name = var.name

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_cidrs
  }
}

resource "hcloud_volume" "data" {
  name     = "${var.name}-data"
  size     = var.data_gb
  location = var.location
}

module "bootstrap" {
  source              = "../../modules/bootstrap"
  data_device         = hcloud_volume.data.linux_device
  t3_channel          = var.t3_channel
  policy_organization = var.policy_organization
  ssh_public_key      = file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_server" "worker" {
  count        = var.running ? 1 : 0
  name         = var.name
  server_type  = var.server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.this.id]
  firewall_ids = [hcloud_firewall.this.id]
  user_data    = module.bootstrap.user_data
}

resource "hcloud_volume_attachment" "data" {
  count     = var.running ? 1 : 0
  volume_id = hcloud_volume.data.id
  server_id = hcloud_server.worker[0].id
  # cloud-init formats and mounts it by label; Hetzner's automount would race that.
  automount = false
}
