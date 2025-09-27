# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.env}"

  setting {
    name  = "containerInsights"
    value = "disabled" # Cost optimization: disable enhanced monitoring
  }

  tags = {
    Name        = "${var.project}-${var.env}"
    Environment = var.env
  }
}

# Launch template for Auto Scaling Group
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project}-${var.env}-"
  image_id      = var.ecs_optimized_ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ecs_tasks.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.root}/../../../scripts/user-data-staging.sh", {
    cluster_name = aws_ecs_cluster.main.name
    region       = var.region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project}-${var.env}-ecs-instance"
      Environment = var.env
      ECSCluster  = aws_ecs_cluster.main.name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                      = "${var.project}-${var.env}-ecs-asg"
  vpc_zone_identifier       = [var.subnet_id]
  target_group_arns         = []
  health_check_type         = "EC2"
  health_check_grace_period = 300

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = false
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.env}-ecs-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.env
    propagate_at_launch = true
  }

  # Instance refresh for automatic updates
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
    # triggers = ["launch_template"]  # コスト優先のため削除
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Cluster Capacity Provider (EC2)
resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project}-${var.env}-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }

    managed_termination_protection = "DISABLED"
  }

  tags = {
    Name        = "${var.project}-${var.env}-ec2-capacity-provider"
    Environment = var.env
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }
}

# IAM Role for ECS Instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project}-${var.env}-ecs-instance-role"

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
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# SSM access for debugging and management
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile for ECS
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project}-${var.env}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-${var.env}-app"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]

  memory     = var.task_memory
  depends_on = [var.ecr_initial_image_dependency]

  container_definitions = jsonencode([
    {
      name      = "mysql"
      image     = "mysql:8.0"
      memory    = var.mysql_memory
      essential = true

      environment = [
        {
          name  = "MYSQL_ROOT_PASSWORD"
          value = var.mysql_root_password
        },
        {
          name  = "MYSQL_DATABASE"
          value = var.mysql_database
        },
        {
          name  = "MYSQL_USER"
          value = var.mysql_user
        },
        {
          name  = "MYSQL_PASSWORD"
          value = var.mysql_password
        },
        {
          name  = "MYSQL_ROOT_HOST"
          value = "%"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "mysql-data"
          containerPath = "/var/lib/mysql"
          readOnly      = false
        }
      ]

      portMappings = [
        {
          containerPort = 3306
          hostPort      = 3306
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD --silent"
        ]
        interval    = 15
        timeout     = 10
        retries     = 5
        startPeriod = 120
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "mysql"
        }
      }
    },
    {
      name      = "backend"
      image     = "${var.ecr_repository_url}:latest"
      memory    = var.backend_memory
      essential = true

      environment = concat([
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "API_PORT"
          value = "3000"
        }
      ], var.backend_environment_variables)

      dependsOn = [
        {
          containerName = "mysql"
          condition     = "HEALTHY"
        }
      ]

      links = ["mysql:mysql"]

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "nc -z localhost 3000 || exit 1"
        ]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])

  volume {
    name      = "mysql-data"
    host_path = "/opt/mysql/data"
  }

  tags = {
    Environment = var.env
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.project}-${var.env}-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  force_new_deployment = true
  depends_on           = [var.ecr_initial_image_dependency]

  # Deployment configuration for resource-constrained environment
  deployment_maximum_percent         = 100 # Don't allow more than 1 task at a time
  deployment_minimum_healthy_percent = 0   # Allow temporary service downtime during deployment

  # Placement constraints to ensure single instance
  placement_constraints {
    type = "distinctInstance"
  }

  # Enable ECS managed tags
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  tags = {
    Environment = var.env
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${var.project}-${var.env}"
  retention_in_days = 7 # Cost optimization: shorter retention

  tags = {
    Environment = var.env
  }
}

# Note: EC2 instance information is obtained dynamically via outputs
# We'll use a separate terraform apply after the ECS infrastructure is ready

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project}-${var.env}-ecs-tasks"
  vpc_id      = var.vpc_id

  # MySQL access
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Backend API access
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # Health checks
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.env}-ecs-tasks"
    Environment = var.env
  }
}
