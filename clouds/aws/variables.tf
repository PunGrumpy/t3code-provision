variable "t3_channel" {
  description = "T3 Code release train. Match the machine you link from."
  type        = string
  default     = "stable"
}

variable "policy_organization" {
  description = "Name T3 Code shows beside settings this VM's managed policy sets."
  type        = string
  default     = "t3code-provision"
}

variable "running" {
  description = "false removes the instance but keeps the data volume, security group and key pair."
  type        = bool
  default     = true
}

variable "name" {
  type    = string
  default = "t3-worker"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "availability_zone" {
  description = "The EBS volume lives in one zone, so the instance must too. Defaults to the region's zone a."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Must be a Nitro type: the data volume is found by its NVMe serial."
  type        = string
  default     = "t3.xlarge"
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
