# Lambda function for automatic Route53 record updates
# Cost-optimized configuration: <$0.15/month

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_function.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-${var.env}-route53-updater"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.env
    Purpose     = "Route53 Record Update"
  }
}

# IAM policy for Lambda (minimal permissions, Route53-based)
# Wait for IAM role propagation
resource "null_resource" "lambda_role_propagation" {
  provisioner "local-exec" {
    command = "sleep 10"
  }

  depends_on = [aws_iam_role.lambda_role]
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project}-${var.env}-route53-updater-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ]
        Resource = [
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project}-${var.env}",
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:container-instance/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      }
    ]
  })
}

# Lambda function (cost-optimized, Route53-based)
resource "aws_lambda_function" "route53_updater" {
  count = var.api_domain != null && var.acm_arn_us_east_1 != null ? 1 : 0

  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.project}-${var.env}-route53-updater"
  role          = aws_iam_role.lambda_role.arn
  handler       = "update_route53.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 128 # Minimal memory for cost optimization

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER_NAME       = module.ecs.cluster_name
      ROUTE53_HOSTED_ZONE_ID = var.route53_zone_id
      ROUTE53_RECORD_NAME    = "backend-${var.env}.studify.click"
    }
  }

  tags = {
    Environment = var.env
    Purpose     = "Route53 Record Update"
  }

  depends_on = [
    aws_iam_role.lambda_role,
    aws_iam_role_policy.lambda_policy,
    null_resource.lambda_role_propagation
  ]
}

# CloudWatch Log Group (cost-optimized)
resource "aws_cloudwatch_log_group" "lambda_logs" {
  count = var.api_domain != null && var.acm_arn_us_east_1 != null ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.route53_updater[0].function_name}"
  retention_in_days = 7 # Short retention for cost optimization

  tags = {
    Environment = var.env
    Purpose     = "Route53 Updater Logs"
  }
}

# EventBridge rule for Auto Scaling Group events
resource "aws_cloudwatch_event_rule" "asg_events" {
  count = var.api_domain != null && var.acm_arn_us_east_1 != null ? 1 : 0

  name        = "${var.project}-${var.env}-asg-events"
  description = "Capture Auto Scaling Group events for Route53 updates"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance Launch Successful", "EC2 Instance Terminate Successful"]
    detail = {
      AutoScalingGroupName = ["${var.project}-${var.env}-ecs-asg"]
    }
  })

  tags = {
    Environment = var.env
    Purpose     = "Route53 Record Update Trigger"
  }
}

# EventBridge target (Lambda)
resource "aws_cloudwatch_event_target" "lambda_target" {
  count = var.api_domain != null && var.acm_arn_us_east_1 != null ? 1 : 0

  rule      = aws_cloudwatch_event_rule.asg_events[0].name
  target_id = "Route53UpdaterTarget"
  arn       = aws_lambda_function.route53_updater[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.api_domain != null && var.acm_arn_us_east_1 != null ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.route53_updater[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_events[0].arn
}
