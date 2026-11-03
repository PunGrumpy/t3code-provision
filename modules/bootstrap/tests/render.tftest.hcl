variables {
  data_device         = "/dev/disk/by-id/virtio-0123456789abcdef0123"
  t3_channel          = "nightly"
  policy_organization = "acme \"ops\""
}

run "renders_valid_cloud_config" {
  command = plan

  assert {
    condition     = startswith(output.user_data, "#cloud-config\n")
    error_message = "cloud-init ignores user_data without the #cloud-config header"
  }

  assert {
    condition     = yamldecode(output.user_data).fs_setup[0].device == var.data_device
    error_message = "fs_setup formats a different disk than the one passed in"
  }

  assert {
    condition     = strcontains(yamldecode(output.user_data).bootcmd[0], "[ -e ${var.data_device} ]")
    error_message = "bootcmd must wait for the same disk fs_setup formats"
  }

  assert {
    condition     = yamldecode(output.user_data).users == ["default"]
    error_message = "without the default user, su -l ubuntu and t3env ssh fail on root-login images"
  }

  assert {
    condition     = yamldecode(output.user_data).fs_setup[0].partition == "auto"
    error_message = "partition must stay auto, or every new instance reformats the data volume"
  }

  assert {
    condition = jsondecode([
      for f in yamldecode(output.user_data).write_files : f.content if f.path == "/etc/t3code/policy.json"
    ][0]).organization == var.policy_organization
    error_message = "policy.json is not valid JSON or lost the organization name"
  }

  assert {
    condition     = strcontains(output.user_data, "export T3CODE_CHANNEL=nightly\n")
    error_message = "the installer would not pick the requested channel"
  }
}

run "rejects_unknown_channel" {
  command = plan
  variables {
    t3_channel = "beta"
  }
  expect_failures = [var.t3_channel]
}
