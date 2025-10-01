data "aws_iam_policy_document" "otel_task_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "aws_otel_role" {
  name               = "opentelemetry-collector-${var.aws_profile}"
  assume_role_policy = data.aws_iam_policy_document.otel_task_assume_role.json

  description = "Allows ECS tasks to call AWS services on your behalf. This is for Open Telemetry collector."
}

data "aws_iam_policy_document" "otel_task_role" {

  statement {
    effect = "Allow"

    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
      "ssm:GetParameters",
      "ssm:StartSession",
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_role_otel_policy" {
#  name = "${var.environment}-AWSOpenTelemetryPolicy"
  name = "opentelemetry-collector-policy-${var.aws_profile}"
  role = aws_iam_role.aws_otel_role.id

  policy = data.aws_iam_policy_document.otel_task_role.json
}

