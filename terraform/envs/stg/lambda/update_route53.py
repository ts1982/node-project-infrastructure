#!/usr/bin/env python3
"""
Cost-optimized Lambda function for updating Route53 record when ECS instances change.
Clean Route53-based design - no CloudFront API calls needed.
Minimal logging, efficient processing, designed for <$0.15/month cost.
"""

import json
import boto3
import logging
from typing import Dict, Any, Optional

# Configure minimal logging (ERROR level only)
logger = logging.getLogger()
logger.setLevel(logging.ERROR)

# Initialize AWS clients (reused across invocations)
ecs_client = boto3.client("ecs")
ec2_client = boto3.client("ec2")
route53_client = boto3.client("route53")


def get_all_ecs_instance_ips(cluster_name: str) -> Dict[str, list]:
    """Get all healthy ECS instance IPs (IPv4 and IPv6) with running tasks."""
    try:
        # Get all active container instances
        container_instances = ecs_client.list_container_instances(
            cluster=cluster_name, status="ACTIVE"
        )

        if not container_instances["containerInstanceArns"]:
            return {"ipv4": [], "ipv6": []}

        # Get detailed instance information including running tasks
        instance_details = ecs_client.describe_container_instances(
            cluster=cluster_name,
            containerInstances=container_instances["containerInstanceArns"],
        )

        # Filter instances that have running tasks
        active_instance_ids = []
        for container_instance in instance_details["containerInstances"]:
            if container_instance["runningTasksCount"] > 0:
                active_instance_ids.append(container_instance["ec2InstanceId"])

        if not active_instance_ids:
            # If no instances have running tasks, fall back to all active instances
            active_instance_ids = [
                ci["ec2InstanceId"] for ci in instance_details["containerInstances"]
            ]

        # Get EC2 instance details for all active instances
        ec2_response = ec2_client.describe_instances(InstanceIds=active_instance_ids)

        ipv4_addresses = []
        ipv6_addresses = []

        for reservation in ec2_response["Reservations"]:
            for instance in reservation["Instances"]:
                # Get IPv4 address
                ipv4 = instance.get("PublicIpAddress")
                if ipv4:
                    ipv4_addresses.append(ipv4)

                # Get IPv6 addresses from network interfaces
                for network_interface in instance.get("NetworkInterfaces", []):
                    for ipv6_addr in network_interface.get("Ipv6Addresses", []):
                        ipv6_addresses.append(ipv6_addr["Ipv6Address"])

        return {"ipv4": ipv4_addresses, "ipv6": ipv6_addresses}

    except Exception as e:
        logger.error(f"Failed to get ECS instance IPs: {str(e)}")
        return {"ipv4": [], "ipv6": []}


def update_route53_records(
    hosted_zone_id: str, record_name: str, ips: Dict[str, list]
) -> bool:
    """Update Route53 A and AAAA records with multiple IP addresses for load balancing."""
    try:
        changes = []

        # Update IPv4 A records if available
        if ips["ipv4"]:
            # Check current A record to avoid unnecessary updates
            current_ipv4_set = set()
            try:
                response = route53_client.list_resource_record_sets(
                    HostedZoneId=hosted_zone_id,
                    StartRecordName=record_name,
                    StartRecordType="A",
                    MaxItems="1",
                )

                if response["ResourceRecordSets"]:
                    current_record = response["ResourceRecordSets"][0]
                    if (
                        current_record["Name"].rstrip(".") == record_name.rstrip(".")
                        and current_record["Type"] == "A"
                    ):
                        current_ipv4_set = {
                            rr["Value"] for rr in current_record["ResourceRecords"]
                        }
            except:
                pass

            new_ipv4_set = set(ips["ipv4"])
            if current_ipv4_set != new_ipv4_set:
                changes.append(
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": record_name,
                            "Type": "A",
                            "TTL": 60,
                            "ResourceRecords": [{"Value": ip} for ip in ips["ipv4"]],
                        },
                    }
                )

        # Update IPv6 AAAA records if available
        if ips["ipv6"]:
            # Check current AAAA record to avoid unnecessary updates
            current_ipv6_set = set()
            try:
                response = route53_client.list_resource_record_sets(
                    HostedZoneId=hosted_zone_id,
                    StartRecordName=record_name,
                    StartRecordType="AAAA",
                    MaxItems="1",
                )

                if response["ResourceRecordSets"]:
                    current_record = response["ResourceRecordSets"][0]
                    if (
                        current_record["Name"].rstrip(".") == record_name.rstrip(".")
                        and current_record["Type"] == "AAAA"
                    ):
                        current_ipv6_set = {
                            rr["Value"] for rr in current_record["ResourceRecords"]
                        }
            except:
                pass

            new_ipv6_set = set(ips["ipv6"])
            if current_ipv6_set != new_ipv6_set:
                changes.append(
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": record_name,
                            "Type": "AAAA",
                            "TTL": 60,
                            "ResourceRecords": [{"Value": ip} for ip in ips["ipv6"]],
                        },
                    }
                )

        # Apply changes if any
        if changes:
            route53_client.change_resource_record_sets(
                HostedZoneId=hosted_zone_id, ChangeBatch={"Changes": changes}
            )

        return True

    except Exception as e:
        logger.error(f"Failed to update Route53 record: {str(e)}")
        return False


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for ECS Auto Scaling Group changes.
    Updates Route53 A and AAAA records with all healthy instance IPs for load balancing.
    """
    try:
        # Extract parameters from environment variables
        import os

        cluster_name = os.environ.get("ECS_CLUSTER_NAME")
        hosted_zone_id = os.environ.get("ROUTE53_HOSTED_ZONE_ID")
        record_name = os.environ.get("ROUTE53_RECORD_NAME")

        if not cluster_name or not hosted_zone_id or not record_name:
            logger.error("Missing required environment variables")
            return {"statusCode": 400, "body": "Missing configuration"}

        # Get all healthy instance IPs (IPv4 and IPv6)
        ips = get_all_ecs_instance_ips(cluster_name)
        if not ips["ipv4"] and not ips["ipv6"]:
            logger.error("No healthy ECS instances found")
            return {"statusCode": 404, "body": "No instances"}

        # Update Route53 records (A and AAAA)
        success = update_route53_records(hosted_zone_id, record_name, ips)

        if success:
            return {
                "statusCode": 200,
                "body": f"Route53 updated - IPv4: {len(ips['ipv4'])}, IPv6: {len(ips['ipv6'])}",
            }
        else:
            return {"statusCode": 500, "body": "Update failed"}

    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {"statusCode": 500, "body": "Internal error"}
