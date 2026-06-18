# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
# Cron expressions are LOCKED to Jakarta WIB (UTC+7).
# Saturday & Sunday: start 8:00 AM WIB, stop 12:00 PM WIB (4-hour session).
# Conversion: 8 AM WIB = 1 AM UTC | 12 PM WIB = 5 AM UTC
#
# EventBridge cron format: cron(Minute Hour Day-of-month Month Day-of-week Year)
# Day-of-week: SUN MON TUE WED THU FRI SAT
# Use ? for Day-of-month when Day-of-week is specified.
# ---------------------------------------------------------------------------

locals {
  schedules = {
    saturday-start = {
      cron   = "cron(0 1 ? * SAT *)"
      action = "start"
    }
    saturday-stop = {
      cron   = "cron(0 5 ? * SAT *)"
      action = "stop"
    }
    sunday-start = {
      cron   = "cron(0 1 ? * SUN *)"
      action = "start"
    }
    sunday-stop = {
      cron   = "cron(0 5 ? * SUN *)"
      action = "stop"
    }
  }

  asg_names = values(var.node_group_asg_names)
}

# ---------------------------------------------------------------------------
# Lambda IAM Role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  count              = var.enabled ? 1 : 0
  name               = "${var.cluster_name}-scheduler-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = var.tags
}

# Basic execution role — gives the Lambda permission to write CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Inline policy — permission to scale the EKS node group ASGs
resource "aws_iam_role_policy" "lambda_asg" {
  count = var.enabled ? 1 : 0
  name  = "${var.cluster_name}-scheduler-asg-policy"
  role  = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["autoscaling:SetDesiredCapacity", "autoscaling:DescribeAutoScalingGroups"]
        Resource = ["arn:aws:autoscaling:${var.region}:*:autoScalingGroup:*"]
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Lambda Function Source Code (packaged inline via archive provider)
# ---------------------------------------------------------------------------

# START Lambda source
data "archive_file" "lambda_start" {
  count       = var.enabled ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.build/start_lambda.zip"

  source {
    content  = <<-PYTHON
      import boto3
      import os
      import json

      def handler(event, context):
          asg_names    = json.loads(os.environ["ASG_NAMES"])
          min_size     = int(os.environ["MIN_SIZE"])
          desired_size = int(os.environ["DESIRED_SIZE"])
          max_size     = int(os.environ["MAX_SIZE"])
          region       = os.environ["REGION"]

          client = boto3.client("autoscaling", region_name=region)

          for asg in asg_names:
              client.update_auto_scaling_group(
                  AutoScalingGroupName=asg,
                  MinSize=min_size,
                  DesiredCapacity=desired_size,
                  MaxSize=max_size
              )
              print(f"[START] ASG '{asg}' -> min={min_size}, desired={desired_size}, max={max_size}")

          return {"statusCode": 200, "body": f"Started {len(asg_names)} ASG(s)"}
    PYTHON
    filename = "index.py"
  }
}

# STOP Lambda source
data "archive_file" "lambda_stop" {
  count       = var.enabled ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.build/stop_lambda.zip"

  source {
    content  = <<-PYTHON
      import boto3
      import os
      import json

      def handler(event, context):
          asg_names = json.loads(os.environ["ASG_NAMES"])
          region    = os.environ["REGION"]

          client = boto3.client("autoscaling", region_name=region)

          for asg in asg_names:
              # Only zero MinSize and DesiredCapacity.  Leave MaxSize at its
              # configured value so the start Lambda can restore capacity with
              # a single successful call (no ordering dependency).
              client.update_auto_scaling_group(
                  AutoScalingGroupName=asg,
                  MinSize=0,
                  DesiredCapacity=0
              )
              print(f"[STOP] ASG '{asg}' -> min=0, desired=0")

          return {"statusCode": 200, "body": f"Stopped {len(asg_names)} ASG(s)"}
    PYTHON
    filename = "index.py"
  }
}

# ---------------------------------------------------------------------------
# Lambda Functions
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "start" {
  count            = var.enabled ? 1 : 0
  function_name    = "${var.cluster_name}-scheduler-start"
  role             = aws_iam_role.lambda[0].arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_start[0].output_path
  source_code_hash = data.archive_file.lambda_start[0].output_base64sha256
  tags             = var.tags

  environment {
    variables = {
      ASG_NAMES    = jsonencode(local.asg_names)
      MIN_SIZE     = tostring(var.start_min_size)
      DESIRED_SIZE = tostring(var.start_desired_size)
      MAX_SIZE     = tostring(var.start_max_size)
      REGION       = var.region
    }
  }
}

resource "aws_lambda_function" "stop" {
  count            = var.enabled ? 1 : 0
  function_name    = "${var.cluster_name}-scheduler-stop"
  role             = aws_iam_role.lambda[0].arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_stop[0].output_path
  source_code_hash = data.archive_file.lambda_stop[0].output_base64sha256
  tags             = var.tags

  environment {
    variables = {
      ASG_NAMES = jsonencode(local.asg_names)
      REGION    = var.region
    }
  }
}

# ---------------------------------------------------------------------------
# EventBridge Rules, Targets, and Lambda Permissions
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "scheduler" {
  for_each            = var.enabled ? local.schedules : {}
  name                = "${var.cluster_name}-${each.key}"
  description         = "EKS scheduler: ${each.key} (Jakarta WIB)"
  schedule_expression = each.value.cron
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "scheduler" {
  for_each  = var.enabled ? local.schedules : {}
  rule      = aws_cloudwatch_event_rule.scheduler[each.key].name
  target_id = "${var.cluster_name}-${each.key}-target"
  arn       = each.value.action == "start" ? aws_lambda_function.start[0].arn : aws_lambda_function.stop[0].arn
}

resource "aws_lambda_permission" "scheduler" {
  for_each      = var.enabled ? local.schedules : {}
  statement_id  = "allow-eventbridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.action == "start" ? aws_lambda_function.start[0].function_name : aws_lambda_function.stop[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler[each.key].arn
}
