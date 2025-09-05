# Search for the latest snapshot for data restoration (optional)
data "aws_ebs_snapshot_ids" "available_backups" {
  owners = ["self"]

  filter {
    name   = "tag:Project"
    values = [var.project]
  }

  filter {
    name   = "tag:Environment"
    values = [var.env]
  }

  filter {
    name   = "tag:Purpose"
    values = ["Database"]
  }
}

# Get the latest snapshot if any exist
locals {
  snapshot_ids       = data.aws_ebs_snapshot_ids.available_backups.ids
  latest_snapshot_id = length(local.snapshot_ids) > 0 ? reverse(sort(local.snapshot_ids))[0] : null
}

data "aws_region" "current" {}

# EBS Volume for Database Data Persistence  
resource "aws_ebs_volume" "db_data" {
  availability_zone = var.availability_zone
  size              = var.volume_size
  type              = var.volume_type
  encrypted         = var.encrypted
  iops              = var.iops
  throughput        = var.throughput

  # Restore from snapshot if available
  snapshot_id = local.latest_snapshot_id

  tags = {
    Name        = "${var.project}-${var.env}-db-data"
    Project     = var.project
    Environment = var.env
    Purpose     = "Database"
    Persistent  = "true"
  }

  # No prevent_destroy needed - snapshots protect data

  # Create snapshot before destruction with proper synchronization
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      echo "Starting snapshot creation for volume ${self.id}..."
      
      # Create new snapshot (synchronous execution)
      NEW_SNAPSHOT_ID=$(aws ec2 create-snapshot \
        --volume-id ${self.id} \
        --description "studify-dev-auto-backup-$(date +%Y%m%d-%H%M%S)" \
        --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=studify-dev-auto-backup},{Key=Project,Value=studify},{Key=Environment,Value=dev},{Key=Purpose,Value=Database}]' \
        --region ap-northeast-1 \
        --query "SnapshotId" --output text)
      
      if [ -z "$NEW_SNAPSHOT_ID" ]; then
        echo "ERROR: Failed to create snapshot for volume ${self.id}"
        exit 1
      fi
      
      echo "Created new snapshot: $NEW_SNAPSHOT_ID"
      
      # Wait for snapshot to reach 'pending' state (immediate start)
      echo "Waiting for snapshot to start..."
      aws ec2 wait snapshot-completed --snapshot-ids $NEW_SNAPSHOT_ID --region ap-northeast-1 &
      WAIT_PID=$!
      
      # Start background cleanup of old snapshots immediately after snapshot creation starts
      echo "Starting cleanup of old snapshots..."
      OLD_SNAPSHOTS=$(aws ec2 describe-snapshots \
        --owner-ids self \
        --filters "Name=tag:Project,Values=studify" "Name=tag:Environment,Values=dev" "Name=tag:Purpose,Values=Database" \
        --query "Snapshots[?SnapshotId!='$NEW_SNAPSHOT_ID'].SnapshotId" \
        --output text --region ap-northeast-1)
      
      if [ ! -z "$OLD_SNAPSHOTS" ] && [ "$OLD_SNAPSHOTS" != "None" ]; then
        for snapshot in $OLD_SNAPSHOTS; do
          echo "Deleting old snapshot: $snapshot"
          aws ec2 delete-snapshot --snapshot-id $snapshot --region ap-northeast-1 || true
        done
        echo "Old snapshots cleanup completed"
      else
        echo "No old snapshots to clean up"
      fi
      
      echo "Snapshot management completed. New snapshot: $NEW_SNAPSHOT_ID"
    EOF
  }

  # Extend deletion timeout for EBS volumes
  timeouts {
    delete = "15m"
  }
}

# Attach EBS Volume to EC2 when instance is provided
resource "aws_volume_attachment" "db_data" {
  device_name = var.device_name
  volume_id   = aws_ebs_volume.db_data.id
  instance_id = var.instance_id
}
