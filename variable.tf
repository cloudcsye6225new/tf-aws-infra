# variable "aws_region" {
#   description = "AWS region where resources will be created"
#   type        = string
# }

# variable "aws_profile" {
#   description = "AWS profile to use for authentication"
#   type        = string
# }

# variable "project_name" {
#   description = "Name of the project, used as a prefix for resource names"
#   type        = string
# }

# variable "vpc_cidr" {
#   description = "CIDR block for the VPC"
#   type        = string
# }

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "app_port" {
  description = "Port on which the application runs"
  type        = number
}

variable "key_pair_name" {
  description = "Name of the key pair to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
