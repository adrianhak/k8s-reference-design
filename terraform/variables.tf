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
  default     = "~/.ssh/id_rsa.pub"
  description = "Key to use"
}

variable "ssh_access_cidr_block" {
  type        = string
  description = "IPs allowed to access master nodes via SSH"
}

variable "region" {
  type        = string
  default     = "eu-north-1"
  description = "The AWS region to deploy resources in"
}

variable "aws_instance_key_name" {
  type        = string
  default     = "main-key"
  description = "Name of AWS key to use"
}