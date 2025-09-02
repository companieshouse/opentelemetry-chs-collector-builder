# Define all hardcoded local variable and local variables looked up from data resources
locals {
  stack_name                  = "search-service" # this must match the stack name the service deploys into
  name_prefix                 = "${local.stack_name}-${var.environment}"
  global_prefix               = "global-${var.environment}"
  service_name                = "opentelemetry-collector-gateway"
  container_port              = "4318"
  eric_port                   = "10000"
  docker_repo                 = "opentelemetry-collector-contrib" #FIXME
  kms_alias                   = "alias/${var.aws_profile}/environment-services-kms"
  lb_listener_rule_priority   = 200
  lb_listener_paths           = [ "/v1/traces", "/v1/metrics", "/v1/logs" ]
  healthcheck_path            = "/v1/traces" #"/health/status" #FIXME
  healthcheck_matcher         = "405"
  vpc_name                    = local.stack_secrets["vpc_name"]
  s3_config_bucket            = data.vault_generic_secret.shared_s3.data["config_bucket_name"]
  application_subnet_ids      = data.aws_subnets.application.ids

  stack_secrets              = jsondecode(data.vault_generic_secret.stack_secrets.data_json)
  application_subnet_pattern = local.stack_secrets["application_subnet_pattern"]

  service_secrets            = jsondecode(data.vault_generic_secret.service_secrets.data_json)

  # create a map of secret name => secret arn to pass into ecs service module
  # using the trimprefix function to remove the prefixed path from the secret name
  secrets_arn_map = {
    for sec in data.aws_ssm_parameter.secret :
    trimprefix(sec.name, "/${local.name_prefix}/") => sec.arn
  }

  global_secrets_arn_map = {
    for sec in data.aws_ssm_parameter.global_secret :
    trimprefix(sec.name, "/${local.global_prefix}/") => sec.arn
  }

  global_secret_list = flatten([for key, value in local.global_secrets_arn_map : 
    { "name" = upper(key), "valueFrom" = value }
  ])

  ssm_global_version_map = [
    for sec in data.aws_ssm_parameter.global_secret : {
      name = "GLOBAL_${var.ssm_version_prefix}${replace(upper(basename(sec.name)), "-", "_")}", value = sec.version
    }
  ]

  service_secrets_arn_map = {
    for sec in module.secrets.secrets:
      trimprefix(sec.name, "/${local.service_name}-${var.environment}/") => sec.arn
  }

  service_secret_list = flatten([for key, value in local.service_secrets_arn_map : 
    { "name" = upper(key), "valueFrom" = value }
  ])

  ssm_service_version_map = [
    for sec in module.secrets.secrets : {
      name = "${replace(upper(local.service_name), "-", "_")}_${var.ssm_version_prefix}${replace(upper(basename(sec.name)), "-", "_")}", value = sec.version
    }
  ]

  # secrets to go in list
  task_secrets = concat(local.service_secret_list,local.global_secret_list,[])

  task_environment = concat(local.ssm_global_version_map,local.ssm_service_version_map,[
    { "name" : "PORT", "value" : local.container_port },
    { "name" : "LOGLEVEL", "value" : var.log_level }
  ])
}

