variable "cloud" {
  description = "Entry in ~/.config/openstack/clouds.yaml."
  type        = string
  default     = "ncp-devops"
}

variable "t3_channel" {
  description = "T3 Code release train. Match the machine you link from."
  type        = string
  default     = "stable"
  validation {
    condition     = contains(["stable", "nightly", "preview"], var.t3_channel)
    error_message = "t3_channel must be stable, nightly or preview."
  }
}

variable "policy_organization" {
  description = "Name T3 Code shows beside settings this VM's managed policy sets."
  type        = string
  default     = "t3code-provision"
}

variable "running" {
  description = "false removes the VM but keeps the data volume, floating IP and key pair."
  type        = bool
  default     = true
}

variable "name" {
  type    = string
  default = "t3-worker"
}

variable "availability_zone" {
  type    = string
  default = "NCP-BKK"
}

variable "flavor_name" {
  type    = string
  default = "csa.xlarge.v2"
}

variable "image_name" {
  description = "Exact Glance image name, from `openstack image list`."
  type        = string
}

variable "network_name" {
  description = "Project network the VM's port joins."
  type        = string
}

variable "floating_ip_pool" {
  description = "External network that hands out floating IPs."
  type        = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_cidrs" {
  description = "Sources allowed to reach port 22. T3 Connect itself needs no inbound port."
  type        = list(string)
}

variable "root_gb" {
  type    = number
  default = 40
}

variable "data_gb" {
  description = "Persistent volume holding ~/.t3, agent logins and ~/workspace."
  type        = number
  default     = 100
}

variable "volume_type" {
  type    = string
  default = null
}
