/*
resource "aws_iam_role" "ecs_task_role" {
  name               = "AWSOTelRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  description = "Allows ECS tasks to call AWS services on your behalf."
}
*/
/*
resource "aws_iam_role_policy" "ecs_task_role_otel_policy" {
  name = "AWSOpenTelemetryPolicy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
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
        Resource = "*"
      }
    ]
  })
}
*/
/*
resource "aws_iam_role" "ecs_execution_role" {
  name               = "AWSOTelExecutionRole"
  description        = "Allows ECS container agent makes calls to the Amazon ECS API on your behalf."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach_ecs_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach_logs_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach_ssm_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}
*/

/*
variable "use_custom_roles" {
  description = "Whether to use custom IAM roles or predefined ARNs"
  type        = bool
  default     = true
}

variable "task_role_arn" {
  description = "Fallback TaskRole ARN if not creating roles"
  type        = string
  default     = "arn:aws:iam::123456789012:role/AWSOTelRole"
}

variable "execution_role_arn" {
  description = "Fallback ExecutionRole ARN if not creating roles"
  type        = string
  default     = "arn:aws:iam::123456789012:role/AWSOTelExecutionRole"
}

variable "command" {
  description = "Command to pass to aws-collector container"
  type        = list(string)
#  default     = [ ]
#  default     = [ "--config=/etc/ecs/ecs-default-config.yaml" ]
  default     = [ "--config", "env:AOT_CONFIG_CONTENT" ]

}
*/

/*
resource "aws_ecs_task_definition" "otel_sidecar" {
  family                   = "ecs-aws-otel-sidecar-service"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "1024"
  memory                  = "2048"

  task_role_arn = var.use_custom_roles ? aws_iam_role.ecs_task_role.arn : var.task_role_arn
  execution_role_arn = var.use_custom_roles ? aws_iam_role.ecs_execution_role.arn : var.execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "aws-collector"
      image = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      # image: otel/opentelemetry-collector:0.86.0 # OTEL Collector image used in docker chs environment
      command = var.command
      cpu    = 256
      memory = 512
      secrets = [
        {
          name      = "AOT_CONFIG_CONTENT"
          valueFrom = aws_ssm_parameter.otel_collector_config.arn #FIXME
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "True"
          awslogs-group         = "/ecs/ecs-aws-otel-sidecar-collector"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command  = ["/healthcheck"]
        interval = 5
        retries  = 2
        timeout  = 3
      }
    },
    {
      name     = "aws-xray-data-emitter"
      image    = "public.ecr.aws/aws-otel-test/aws-otel-goxray-sample-app:latest"
      essential = false
      cpu      = 256
      memory   = 512
      dependsOn = [{
        containerName = "aws-collector"
        condition     = "START"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "True"
          awslogs-group         = "/ecs/ecs-aws-xray-sidecar-emitter"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name     = "nginx"
      image    = "public.ecr.aws/nginx/nginx:latest"
      essential = false
      cpu      = 256
      memory   = 512
      dependsOn = [{
        containerName = "aws-collector"
        condition     = "START"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "True"
          awslogs-group         = "/ecs/nginx"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name     = "aoc-statsd-emitter"
      image    = "public.ecr.aws/amazonlinux/amazonlinux:latest"
      essential = false
      cpu      = 256
      memory   = 512
      dependsOn = [{
        containerName = "aws-collector"
        condition     = "START"
      }]
      entryPoint = [
        "/bin/sh",
        "-c",
        "yum install -y socat; while true; do echo 'statsdTestMetric:1|c' | socat -v -t 0 - UDP:127.0.0.1:8125; sleep 1; done"
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "True"
          awslogs-group         = "/ecs/statsd-emitter"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}
*/
/*
variable "ecs_cluster_name" {
  description = "The name or ARN of the ECS cluster"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for Fargate tasks"
  type        = list(string)
}

variable "security_groups" {
  description = "List of security group IDs for the service"
  type        = list(string)
}
*/

/*
data "aws_security_group" "ecs_service_fargate_sg" {
  tags                    = {
    Environment = var.environment
    Name        = "${var.environment}-${local.service_name}-sg"
  }
}
*/

/*
resource "aws_ecs_service" "aws_otel_sidecar" {
  name            = "aws-otel-sidecar-service"
  cluster         =  "search-service-cidev-cluster" #local.stack_name #var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.otel_sidecar.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  scheduling_strategy = "REPLICA"
  enable_execute_command = true # FIXME: To enable ECS SSH access to the container

  network_configuration {
    subnets         =  data.aws_subnets.application.ids #var.subnets
    security_groups =  [data.aws_security_group.ecs_service_fargate_sg.id] #var.security_groups
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition] # Optional: to avoid service redeploy on minor definition changes
  }
}
*/