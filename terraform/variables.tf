
variable "name" {
  description = "Prefix used to name various infrastructure components. Alphanumeric characters only."
  default     = "biosentinel"
}

variable "region" {
  description = "The AWS region to deploy to."
  default = "us-east-1"
}

variable "allowlist_ip" {
  description = "IP to allow access for the security groups (set 0.0.0.0/0 for world)"
  default     = "0.0.0.0/0"
}

variable "server_instance_type" {
  description = "The AWS instance type to use for servers."
  default     = "t2.micro"
}

variable "client_instance_type" {
  description = "The AWS instance type to use for clients."
  default     = "t2.medium"
}

variable "server_count" {
  description = "The number of servers to provision."
  default     = "2"
}

variable "client_count" {
  description = "The number of clients to provision."
  default     = "3"
}

variable "root_block_device_size" {
  description = "The volume size of the root block device."
  default     = 16
}

variable "nomad_version" {
  description = "The version of the Nomad binary to install."
  default     = "1.9.3"
}
variable "certificate" {
  description = "arn do certificado ACM"
  type        = string
  default     = "arn:aws:acm:us-east-1:345137894335:certificate/8e60e1c1-5137-4648-8875-b6f8e01ccdc1"
}
variable "zone" {
  description = "id da zone"
  type        = string 
  default     = "Z02746573RYJGL6K3HRTX"
}