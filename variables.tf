variable "environment" {
  type = string

}
variable "uniqueName" {
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
  default = 3
}
