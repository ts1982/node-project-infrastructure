output "volume_id" {
  description = "ID of the EBS volume"
  value       = aws_ebs_volume.db_data.id
}

output "volume_arn" {
  description = "ARN of the EBS volume"
  value       = aws_ebs_volume.db_data.arn
}

output "volume_size" {
  description = "Size of the EBS volume"
  value       = aws_ebs_volume.db_data.size
}

output "attachment_id" {
  description = "ID of the volume attachment"
  value       = aws_volume_attachment.db_data.id
}

output "device_name" {
  description = "Device name of the volume attachment"
  value       = var.device_name
}
