mock_provider "openstack" {}

override_resource {
  target = openstack_blockstorage_volume_v3.data
  values = { id = "0123456789abcdef0123456789abcdef" }
}

variables {
  image_name          = "ubuntu"
  network_name        = "default"
  floating_ip_pool    = "public"
  ssh_cidrs           = ["203.0.113.10/32"]
  ssh_public_key_path = "tests/id_test.pub"
}

run "vm_formats_the_attached_volume" {
  variables {
    t3_channel          = "nightly"
    policy_organization = "acme ops"
  }

  assert {
    condition     = strcontains(openstack_compute_instance_v2.worker[0].user_data, "export T3CODE_CHANNEL=nightly\n") && strcontains(openstack_compute_instance_v2.worker[0].user_data, "\"organization\": \"acme ops\"")
    error_message = "the root does not pass t3_channel and policy_organization through to cloud-init"
  }

  assert {
    condition     = yamldecode(openstack_compute_instance_v2.worker[0].user_data).fs_setup[0].device == "/dev/disk/by-id/virtio-0123456789abcdef0123"
    error_message = "cloud-init looks for the data volume under the wrong virtio serial"
  }
}

run "down_keeps_the_volume" {
  variables {
    running = false
  }

  assert {
    condition     = length(openstack_compute_instance_v2.worker) == 0 && openstack_blockstorage_volume_v3.data.size == var.data_gb
    error_message = "running=false must drop the VM and keep the data volume"
  }
}
