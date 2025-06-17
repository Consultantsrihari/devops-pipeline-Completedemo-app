# variables.tf
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "devops-demo-app"
}

variable "app_port" {
  description = "Port the application runs on"
  type        = number
  default     = 3000
}
