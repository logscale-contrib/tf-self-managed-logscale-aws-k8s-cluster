variable "uniqueName" {
  type        = string
  description = "(optional) describe your variable"
}
variable "region" {
  type        = string
  description = "(optional) describe your variable"
}
variable "vpc_id" {
  type        = string
  description = "(optional) describe your variable"
}

variable "vpc_public_subnets" {
  type = list(string)
}
variable "vpc_private_subnets" {
  type = list(string)
}

variable "aws_admin_arn" {
  type        = string
  description = "(optional) describe your variable"
}

variable "eks_general_instance_type" {
  type    = list(any)
  default = ["c6i.xlarge"]
}

variable "eks_general_min_size" {
  type    = number
  default = 2
}
variable "eks_general_max_size" {
  type    = number
  default = 5
}
variable "eks_general_desired_size" {
  type    = number
  default = 2
}

variable "cluster_ip_family" {
  type        = string
  default     = null
  description = "(optional) describe your variable"
}
variable "create_cni_ipv6_iam_policy" {
  type        = bool
  default     = false
  description = "(optional) describe your variable"
}
