variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name for triggering service updates"
  type        = string
  default     = ""
}

variable "service_name" {
  description = "ECS service name for triggering service updates"
  type        = string
  default     = ""
}
