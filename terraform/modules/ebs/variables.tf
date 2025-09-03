variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the EBS volume"
  type        = string
}

variable "volume_size" {
  description = "Size of the EBS volume in GB"
  type        = number
  default     = 5
}

variable "volume_type" {
  description = "Type of EBS volume"
  type        = string
  default     = "gp3"
}

variable "encrypted" {
  description = "Whether to encrypt the EBS volume"
  type        = bool
  default     = true
}

variable "iops" {
  description = "IOPS for the EBS volume (only for gp3, io1, io2)"
  type        = number
  default     = 3000
}

variable "throughput" {
  description = "Throughput for the EBS volume (only for gp3)"
  type        = number
  default     = 125
}

variable "device_name" {
  description = "Device name for the EBS volume attachment"
  type        = string
  default     = "/dev/sdf"
}

variable "instance_id" {
  description = "EC2 instance ID to attach the volume to (optional)"
  type        = string
  default     = null
}
