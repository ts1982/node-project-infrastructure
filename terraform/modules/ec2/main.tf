# Data source for Amazon Linux 2 AMI (smaller footprint)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for EC2
resource "aws_security_group" "ec2" {
  name        = "${var.project}-${var.env}-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # Backend API (port 3000)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.env}-ec2-sg"
    Project     = var.project
    Environment = var.env
  }
}

# IAM Role for EC2 (SSM Session Manager)
resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-${var.env}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-ec2-role"
    Project     = var.project
    Environment = var.env
  }
}

# Attach SSM Managed Instance Core policy
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach ECR Read Only policy for container deployment
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Custom policy for Secrets Manager access
resource "aws_iam_policy" "secrets_manager_read" {
  name        = "${var.project}-${var.env}-secrets-manager-read"
  description = "Policy to read from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.backend_secret_arn,
          var.mysql_secret_arn
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-secrets-manager-read"
    Project     = var.project
    Environment = var.env
  }
}

# Attach Secrets Manager policy
resource "aws_iam_role_policy_attachment" "secrets_manager_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_manager_read.arn
}

# SES sending policy
resource "aws_iam_policy" "ses_send_email" {
  name        = "${var.project}-${var.env}-ses-send-email"
  description = "Policy for sending emails through SES"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-ses-send-email"
    Project     = var.project
    Environment = var.env
  }
}

# Attach SES policy
resource "aws_iam_role_policy_attachment" "ses_send_email" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ses_send_email.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-${var.env}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${var.project}-${var.env}-ec2-profile"
    Project     = var.project
    Environment = var.env
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.root}/../../../scripts/user-data.sh", {
    backend_secret_arn  = var.backend_secret_arn
    mysql_secret_arn    = var.mysql_secret_arn
    aws_region          = var.aws_region
    aws_account_id      = var.aws_account_id
    ecr_repository_name = var.ecr_repository_name
    ebs_device_path     = var.ebs_device_path
    mysql_data_dir      = var.mysql_data_dir
    ebs_wait_timeout    = var.ebs_wait_timeout
  }))

  tags = {
    Name        = "${var.project}-${var.env}-ec2"
    Environment = var.env
    Project     = var.project
  }
}
