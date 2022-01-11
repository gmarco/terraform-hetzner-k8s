variable hcloud_token {
  type=string
}

variable cluster_name {
  type=string
  default="kubernetes"
}

variable "location" {
  type = string
  default = "nbg1"
}
variable "worker_nodes" {
  type = number
  default =2
}

variable "master_nodes" {
  type = number
  default =2
}

variable "datacenter" {
  description = "Hetzner datacenter where resources resides, hel1-dc2 (Helsinki 1 DC 2) or fsn1-dc14 (Falkenstein 1 DC14)"
  default     = "nbg1-dc2"
}

variable "image" {
  description = "Node boot image"
  default     = "ubuntu-20.04"
}

variable "master_type" {
  description = "Master node type (size)"
  default     = "cx11" # 2 vCPU, 4 GB RAM, 40 GB Disk space
}

variable "node_type" {
  description = "Node type (size)"
  default     = "cx11" # 2 vCPU, 4 GB RAM, 40 GB Disk space
  validation {
    condition     = can(regex("^cx11$|^cpx11$|^cx21$|^cpx21$|^cx31$|^cpx31$|^cx41$|^cpx41$|^cx51$|^cpx51$|^ccx11$|^ccx21$|^ccx31$|^ccx41$|^ccx51$", var.node_type))
    error_message = "Node type is not valid."
  }
}
