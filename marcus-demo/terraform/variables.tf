variable "vpc_id" {
  type        = string
  description = "Working VPC ID"
}

variable "master_node_count" {
  type        = string
  default     = 1
  description = "Number of master nodes to create"
}

variable "worker_node_count" {
  type        = string
  default     = 1
  description = "Number of workers nodes to create"
}

variable "ssh_key_private" {
  type        = string
  default     = "~/.ssh/marcus-kubernetes-key"
  description = "Key to use"
}
