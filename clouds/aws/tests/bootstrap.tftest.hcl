mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }
}

override_resource {
  target = aws_ebs_volume.data
  values = { id = "vol-0123456789abcdef0" }
}

variables {
  ssh_cidrs           = ["203.0.113.10/32"]
  ssh_public_key_path = "tests/id_test.pub"
}

run "vm_formats_the_attached_volume" {
  variables {
    t3_channel          = "nightly"
    policy_organization = "acme ops"
  }

  assert {
    condition     = strcontains(aws_instance.worker[0].user_data, "export T3CODE_CHANNEL=nightly\n") && strcontains(aws_instance.worker[0].user_data, "\"organization\": \"acme ops\"")
    error_message = "the root does not pass t3_channel and policy_organization through to cloud-init"
  }

  assert {
    condition     = yamldecode(aws_instance.worker[0].user_data).fs_setup[0].device == "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol0123456789abcdef0"
    error_message = "cloud-init looks for the data volume under the wrong NVMe serial"
  }
}

run "down_keeps_the_volume" {
  variables {
    running = false
  }

  assert {
    condition     = length(aws_instance.worker) == 0 && length(aws_volume_attachment.data) == 0 && aws_ebs_volume.data.size == var.data_gb
    error_message = "running=false must drop the instance and keep the data volume"
  }
}
