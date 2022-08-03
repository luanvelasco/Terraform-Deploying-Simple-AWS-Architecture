##################################################################################
# PROVIDERS
##################################################################################
variable "aws_region" {
  type        = string
  description = "AWS Region to use for resources"
  default     = "us-east-1"
}

##################################################################################
# RESOURCES
##################################################################################

variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames in VPC"
  default     = true
}

variable "vpc_cidr_block" {
  type        = string
  description = "Base CIDR Block for VPC"
  default     = "10.0.0.0/16"
}

variable "vpc_subnets_cidr_block" {
  type        = list(string)
  description = "CIDR Block for Subnets in VPC"
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "map_public_ip_on_launch" {
  type        = bool
  description = "Map a public IP address for Subnet instances"
  default     = true
}

variable "aws_instance_type" {
  type        = map(string)
  description = "AWS EC2 instances types"
  default = {
    small  = "t2.micro"
    medium = "t2.small"
    large  = "t2.large"
  }

}

variable "company" {
  type        = string
  description = "Company name for resouce tagging"
  default     = "Globomantics"
}

variable "project" {
  type        = string
  description = "Project name for resouce tagging"
}

variable "billing_code" {
  type        = string
  description = "Billing code for resouce tagging"
}
