#!/bin/bash

# ECS Staging Environment User Data Script
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== ECS Setup Starting ==="
echo "Date: $(date)"
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'unknown')"

# Configure ECS cluster
ECS_CLUSTER_NAME="${cluster_name}"
echo "Cluster: $ECS_CLUSTER_NAME"
echo "ECS_CLUSTER=$ECS_CLUSTER_NAME" > /etc/ecs/ecs.config

# EBS Volume Setup for MySQL persistence
echo "=== Setting up EBS Volume for MySQL ==="
EBS_DEVICE="/dev/sdf"  # Standard AWS EBS device
MYSQL_DATA_DIR="/opt/mysql/data"
EBS_WAIT_TIMEOUT=60

# Wait for EBS device to be available
EBS_WAIT_COUNT=0
while [ ! -e $EBS_DEVICE ]; do
    if [ $EBS_WAIT_COUNT -ge $EBS_WAIT_TIMEOUT ]; then
        echo "ERROR: EBS device $EBS_DEVICE not found after $EBS_WAIT_TIMEOUT seconds"
        exit 1
    fi
    echo "Waiting for EBS device $EBS_DEVICE... ($EBS_WAIT_COUNT/$EBS_WAIT_TIMEOUT)"
    sleep 1
    EBS_WAIT_COUNT=$((EBS_WAIT_COUNT + 1))
done

echo "EBS device $EBS_DEVICE found"

# Format EBS device if not already formatted
if ! blkid $EBS_DEVICE; then
    echo "Formatting EBS device $EBS_DEVICE with ext4..."
    mkfs.ext4 $EBS_DEVICE
fi

# Create mount directory and mount EBS volume
mkdir -p $MYSQL_DATA_DIR
mount $EBS_DEVICE $MYSQL_DATA_DIR
echo "$EBS_DEVICE $MYSQL_DATA_DIR ext4 defaults,nofail 0 2" >> /etc/fstab

# Set proper permissions for MySQL container
MYSQL_CONTENT=$(ls -A "$MYSQL_DATA_DIR" 2>/dev/null | grep -v "lost+found" | wc -l)
if [ "$MYSQL_CONTENT" -eq 0 ]; then
    echo "EBS volume is empty - setting up for first time"
    chown -R 999:999 $MYSQL_DATA_DIR  # MySQL user ID in container
    chmod 755 $MYSQL_DATA_DIR
    find $MYSQL_DATA_DIR -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} \; 2>/dev/null || true
else
    echo "EBS volume has existing data - setting permissions"
    chown -R 999:999 $MYSQL_DATA_DIR
    chmod 755 $MYSQL_DATA_DIR
fi

echo "EBS volume mounted and configured: $MYSQL_DATA_DIR"

echo "=== ECS Setup Completed ==="
echo "Final timestamp: $(date)"