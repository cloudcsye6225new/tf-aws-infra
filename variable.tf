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

}
variable "db_engine" {
  description = "Database engine type (e.g., MySQL, PostgreSQL)"
  type        = string

}

variable "db_username" {
  description = "Master username for the database"
  type        = string
}

variable "db_password" {
  description = "Master password for the database"
  type        = string
}

variable "db_instance_identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_port" {
  description = "Database port (3306 for MySQL/MariaDB, 5432 for PostgreSQL)"
  type        = number
}
variable "db_engine_family" {
  description = "db version which we are using"
  type        = string
}
variable "domain_name" {
  description = "This is the domain name"
  type        = string
}

variable "cpu_high" {
  description = "This is cpu high value"

}
variable "cpu_low" {
  description = "This is cpu low value"
}

variable "send_grid_api_key" {
  description = "This is an Api Key"

}

variable "demo_account_id" {


}
variable "dev_account_id" {

}
