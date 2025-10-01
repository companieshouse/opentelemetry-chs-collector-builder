data "vault_generic_secret" "secrets" {
  path = "applications/${var.aws_profile}/${var.environment}/${local.stack_fullname}"
}

data "aws_subnets" "application" {
  filter {
    name   = "tag:Name"
    values = [local.application_subnet_pattern]
  }
  filter {
    name   = "tag:NetworkType"
    values = ["private"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = [local.application_subnet_pattern]
  }
  filter {
    name   = "tag:NetworkType"
    values = ["private"]
  }
}

data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [local.vpc_name]
  }
}

data "aws_subnets" "management" {
  filter {
    name   = "tag:Name"
    values = [local.application_subnet_pattern]
  }
  filter {
    name   = "tag:Service"
    values = ["management"]
  }
}

data "aws_subnet" "management" {
  for_each = toset(data.aws_subnets.management.ids)
  id       = each.value
}

data "aws_acm_certificate" "cert" {
  domain = var.cert_domain
}

data "aws_subnet" "routing_subnets" {
  count  = length(local.stack_secrets["routing_subnet_pattern"])
  vpc_id = data.aws_vpc.vpc.id
  filter {
    name   = "tag:Name"
    values = [local.stack_secrets["routing_subnet_pattern"][count.index]]
  }
}

data "aws_ec2_managed_prefix_list" "admin" {
  name = "administration-cidr-ranges"
}

