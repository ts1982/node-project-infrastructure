# EBS Volume for Database Data Persistence
resource "aws_ebs_volume" "db_data" {
  availability_zone = var.availability_zone
  size              = var.volume_size
  type              = var.volume_type
  encrypted         = var.encrypted
  iops              = var.iops
  throughput        = var.throughput

  tags = {
    Name        = "${var.project}-${var.env}-db-data"
    Project     = var.project
    Environment = var.env
    Purpose     = "Database"
    Persistent  = "true"
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

# Attach EBS Volume to EC2 when instance is provided
resource "aws_volume_attachment" "db_data" {
  device_name = var.device_name
  volume_id   = aws_ebs_volume.db_data.id
  instance_id = var.instance_id
}
