# Define all hardcoded local variable and local variables looked up from data resources
locals {
  stack_name                  = "search-service" # this must match the stack name the service deploys into # FIXME: opentelemetry-collector-cluster
  name_prefix                 = "${local.stack_name}-${var.environment}"
  global_prefix               = "global-${var.environment}"
  service_name                = "opentelemetry-chs-collector" #FIXME: opentelemetry-collector
  container_port              = "4318"
  healthcheck_port            = "13133"
  docker_repo                 = "opentelemetry-chs-collector" #FIXME: opentelemetry-collector
  kms_alias                   = "alias/${var.aws_profile}/environment-services-kms"
  lb_listener_rule_priority   = 220
  lb_listener_paths           = [ "/v1/traces", "/v1/metrics", "/v1/logs" ]
  healthcheck_path            = "/health" #"/health" #"/v1/traces" #FIXME
  healthcheck_matcher         = "200" #"200" #"405" #FIXME
  vpc_name                    = local.stack_secrets["vpc_name"]
  application_subnet_ids      = data.aws_subnets.application.ids

  stack_secrets              = jsondecode(data.vault_generic_secret.stack_secrets.data_json)
  application_subnet_pattern = local.stack_secrets["application_subnet_pattern"]

}
