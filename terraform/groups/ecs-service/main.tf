provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
  }
  required_version = "~> 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.54.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.18.0"
    }
  }
}


module "ecs-service-otel-collector-gateway" {
  count  = var.environment == "cidev" ? 1 : 0
  source = "git@github.com:companieshouse/terraform-modules//aws/ecs/ecs-service?ref=feature/CC-2096-open-telemetry-spike"

  # Environmental configuration
  environment             = var.environment
  aws_region              = var.aws_region
  aws_profile             = var.aws_profile
  vpc_id                  = data.aws_vpc.vpc.id
  ecs_cluster_id          = data.aws_ecs_cluster.ecs_cluster.id
  #task_role_arn           = aws_iam_role.aws_otel_role.arn #FIXME
  task_execution_role_arn = data.aws_iam_role.ecs_cluster_iam_role.arn

  # Load balancer configuration
  # FIXME: serve with the new load balancer
  lb_listener_arn                 = data.aws_lb_listener.service_lb_listener.arn
  lb_listener_rule_priority       = local.lb_listener_rule_priority
  lb_listener_paths               = local.lb_listener_paths

  # ECS Task container health check
  use_task_container_healthcheck = false
  # FIXME http://localhost:13133/health/status
  healthcheck_path               = local.healthcheck_path
  healthcheck_matcher            = local.healthcheck_matcher

  # Docker container details
  docker_registry   = "otel" #FIXME
  docker_repo       = local.docker_repo
  container_version = "0.128.0" #FIXME
  container_port    = local.container_port

  # Service configuration
  service_name = local.service_name
  name_prefix  = local.name_prefix

  # Service performance and scaling configs
  desired_task_count                 = var.desired_task_count
  max_task_count                     = var.max_task_count
  required_cpus                      = var.required_cpus
  required_memory                    = var.required_memory
  service_autoscale_enabled          = false # FIXME
  service_autoscale_target_value_cpu = var.service_autoscale_target_value_cpu
  service_scaledown_schedule         = var.service_scaledown_schedule
  service_scaleup_schedule           = var.service_scaleup_schedule
  use_capacity_provider              = var.use_capacity_provider
  use_fargate                        = var.use_fargate
  fargate_subnets                    = local.application_subnet_ids

  # Cloudwatch
  cloudwatch_alarms_enabled = false

  # Service environment variable and secret configs
  task_environment            = []
  task_secrets                = [
    {
      "name": "AOT_CONFIG_CONTENT",
      "valueFrom": aws_ssm_parameter.otel_collector_config.arn #FIXME
    }
  ]
  use_set_environment_files   = false

  # eric options for eric running API module
  use_eric_reverse_proxy    = false

  # OTEL Collector side car configurations
  create_otel_collector_gateway = true
  use_otel_collector_gateway  = false
  use_main_application  = false
  enable_execute_command = false # FIXME
  read_only_root_filesystem = true # FIXME
  container_command = [ "--config",  "env:AOT_CONFIG_CONTENT" ]

}

resource "aws_ssm_parameter" "otel_collector_config" {
  name        = "/${local.stack_name}-opentelemetry-collector-gateway-${var.environment}/otel-collector-config"
  description = "OpenTelemetry Collector Gateway Configuration"
  type        = "String"
  tier        = "Standard"
  data_type   = "text"
  value       = file("${path.module}/gateway-otel-collector-config.yaml") # or use inline value
}

module "secrets" {
  source = "git@github.com:companieshouse/terraform-modules//aws/ecs/secrets?ref=1.0.341"

  name_prefix = "${local.service_name}-${var.environment}"
  environment = var.environment
  kms_key_id  = data.aws_kms_key.kms_key.id
  secrets     = nonsensitive(local.service_secrets)
}
