locals {
  lb_name                         = "otel-collector"
  stack_name                      = "opentelemetry-collector"
  stack_fullname                  = "${local.stack_name}-service-stack"
  name_prefix                     = "${local.stack_name}-${var.environment}"

  stack_secrets                   = jsondecode(data.vault_generic_secret.secrets.data_json)

  application_subnet_pattern      = local.stack_secrets["application_subnet_pattern"]
  application_subnet_ids          = join(",", data.aws_subnets.application.ids)

  vpc_name                        = local.stack_secrets["vpc_name"]
  notify_topic_slack_endpoint     = local.stack_secrets["notify_topic_slack_endpoint"]

  routing_subnet_ids              = zipmap(
                                        data.aws_subnet.routing_subnets.*.availability_zone,
                                        data.aws_subnet.routing_subnets.*.id
                                    )

  management_private_subnet_cidrs = [for subnet in data.aws_subnet.management : subnet.cidr_block]
  application_cidrs               = [for subnet in data.aws_subnet.private : subnet.cidr_block]
  ingress_cidrs_private           = concat(local.management_private_subnet_cidrs, local.application_cidrs)

  ingress_prefix_list_ids         = [data.aws_ec2_managed_prefix_list.admin.id]

  lb_subnet_ids                   = values(local.routing_subnet_ids)
}
