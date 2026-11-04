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
  description = "false removes the server but keeps the data volume, firewall and SSH key."
  type        = bool
  default     = true
}

variable "name" {
  type    = string
  default = "t3-worker"
}

variable "location" {
  description = "Hetzner location, from `hcloud location list`. The volume and server must share it."
  type        = string
  default     = "sin"
}

variable "server_type" {
  description = "From `hcloud server-type list`. Not every type is sold in every location."
  type        = string
}

variable "image" {
  type    = string
  default = "ubuntu-24.04"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_cidrs" {
  description = "Sources allowed to reach port 22. T3 Connect itself needs no inbound port."
  type        = list(string)
}

variable "data_gb" {
  description = "Persistent volume holding ~/.t3, agent logins and ~/workspace."
  type        = number
  default     = 100
}
