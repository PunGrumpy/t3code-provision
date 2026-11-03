# hcloud ids are numbers; the mock's random strings would fail type checks.
mock_provider "hcloud" {
  mock_resource "hcloud_ssh_key" {
    defaults = { id = "1" }
  }
  mock_resource "hcloud_firewall" {
    defaults = { id = "2" }
  }
  mock_resource "hcloud_server" {
    defaults = { id = "3", ipv4_address = "198.51.100.7" }
  }
}

override_resource {
  target = hcloud_volume.data
  values = { id = "4242", linux_device = "/dev/disk/by-id/scsi-0HC_Volume_4242" }
}

variables {
  server_type         = "cpx31"
  ssh_cidrs           = ["203.0.113.10/32"]
  ssh_public_key_path = "tests/id_test.pub"
}

run "vm_formats_the_attached_volume" {
  variables {
    t3_channel          = "nightly"
    policy_organization = "acme ops"
  }

  assert {
    condition     = strcontains(hcloud_server.worker[0].user_data, "export T3CODE_CHANNEL=nightly\n") && strcontains(hcloud_server.worker[0].user_data, "\"organization\": \"acme ops\"")
    error_message = "the root does not pass t3_channel and policy_organization through to cloud-init"
  }

  assert {
    condition     = yamldecode(hcloud_server.worker[0].user_data).fs_setup[0].device == "/dev/disk/by-id/scsi-0HC_Volume_4242"
    error_message = "cloud-init looks for the data volume somewhere other than Hetzner's linux_device"
  }

  assert {
    condition     = hcloud_volume_attachment.data[0].automount == false
    error_message = "Hetzner's automount would mount the volume before cloud-init labels it"
  }
}

run "down_keeps_the_volume" {
  variables {
    running = false
  }

  assert {
    condition     = length(hcloud_server.worker) == 0 && length(hcloud_volume_attachment.data) == 0 && hcloud_volume.data.size == var.data_gb
    error_message = "running=false must drop the server and keep the data volume"
  }
}
