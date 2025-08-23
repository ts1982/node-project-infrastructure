variable "project" {
  description = "Project name"
  type        = string
  default     = "studify"
}

variable "env" {
  description = "Environment"
  type        = string
}

variable "backend_secret_name" {
  description = "Name for the backend secrets"
  type        = string
}

variable "mysql_secret_name" {
  description = "Name for the MySQL secrets"
  type        = string
}

variable "backend_secrets" {
  description = "Backend application secrets"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "mysql_secrets" {
  description = "MySQL database secrets"
  type        = map(string)
  default     = {}
  sensitive   = true
}
