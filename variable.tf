variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
}

variable "project_name" {
  description = "Name of the project, used as a prefix for resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}