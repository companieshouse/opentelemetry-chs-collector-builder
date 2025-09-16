terraform {
  backend "s3" {}
  required_version = ">= 1.3, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0, < 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
}

module "alb" {
  source                  = "git@github.com:companieshouse/terraform-modules//aws/application_load_balancer?ref=1.0.343"
  environment             = var.environment
  service                 = local.lb_name
  ssl_certificate_arn     = data.aws_acm_certificate.cert.arn
  subnet_ids              = local.lb_subnet_ids
  vpc_id                  = data.aws_vpc.vpc.id
  route53_aliases         = var.route53_aliases
  route53_domain_name     = var.route53_domain_name

  create_security_group   = true
  internal                = true
  ingress_cidrs           = local.ingress_cidrs_private
  ingress_prefix_list_ids = local.ingress_prefix_list_ids
  service_configuration = {
    listener_config = {
      listener_config = {
        default_action_type = "fixed-response"
        port                = 443
        fixed_response = {
          status_code  = 404
        }
      }
    }
  }
}


module "ecs-cluster" {
  source = "git@github.com:companieshouse/terraform-modules//aws/ecs/ecs-cluster?ref=1.0.343"

  stack_name                  = local.stack_name
  name_prefix                 = local.name_prefix
  environment                 = var.environment
  aws_profile                 = var.aws_profile
  vpc_id                      = data.aws_vpc.vpc.id
  subnet_ids                  = local.application_subnet_ids
  ec2_instance_type           = var.ec2_instance_type
  asg_max_instance_count      = var.asg_max_instance_count
  asg_min_instance_count      = var.asg_min_instance_count
  enable_container_insights   = var.enable_container_insights
  asg_desired_instance_count  = var.asg_desired_instance_count
  scaledown_schedule          = var.asg_scaledown_schedule
  scaleup_schedule            = var.asg_scaleup_schedule
  enable_asg_autoscaling      = var.enable_asg_autoscaling
  notify_topic_slack_endpoint = local.notify_topic_slack_endpoint
}
