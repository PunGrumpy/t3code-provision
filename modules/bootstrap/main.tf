variable "data_device" {
  description = "Stable path of the data volume inside the guest. Each cloud names attached disks differently."
  type        = string
  validation {
    condition     = startswith(var.data_device, "/dev/disk/by-")
    error_message = "data_device must be a /dev/disk/by-* path, which survives device reordering."
  }
}

variable "t3_channel" {
  description = "T3 Code release train. Match the machine you link from."
  type        = string
  validation {
    condition     = contains(["stable", "nightly", "preview"], var.t3_channel)
    error_message = "t3_channel must be stable, nightly or preview."
  }
}

variable "ssh_public_key" {
  description = "Key for the ubuntu user, which t3env logs in as."
  type        = string
}

variable "policy_organization" {
  description = "Name T3 Code shows beside settings this VM's managed policy sets."
  type        = string
}

output "user_data" {
  value = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    data_device         = var.data_device
    t3_channel          = var.t3_channel
    policy_organization = var.policy_organization
    ssh_public_key      = trimspace(var.ssh_public_key)
  })
}
