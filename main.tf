terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.31.0"
    }
  }
  backend "local" {}
}

provider "aws" {
  region      = "<MY_REGION>"
  profile     = "<MY_AWS_PROFILE>"
  max_retries = 2
}

locals {
  repository_name         = "myrepository"
  cluster_name            = "<MY_K8S_CLUSTER_NAME>"
  role_name               = "myrole"
  namespace               = "<MY_K8S_NAMESPASE>"
  policy_name			  = "mypolicy"
}

resource "aws_ecr_repository" "repository" {
  name                 = local.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

data "aws_iam_policy_document" "otel_policy_document" {
  statement {
    effect    = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
	  "xray:GetSamplingStatisticSummaries",
	  "logs:CreateLogStream",
	  "xray:PutTelemetryRecords",
	  "logs:DescribeLogGroups",
	  "logs:DescribeLogStreams",
	  "xray:GetSamplingRules",
	  "ssm:GetParameters",
	  "xray:GetSamplingTargets",
	  "logs:CreateLogGroup",
	  "logs:PutLogEvents",
	  "xray:PutTraceSegments"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "otel_policy" {
  name   = local.policy_name
  path   = "/"
  policy = data.aws_iam_policy_document.otel_policy_document.json
}

data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

module "iam_assumable_role_with_oidc" {
  source                       = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                      = "4.14.0"
  oidc_subjects_with_wildcards = ["system:serviceaccount:${local.namespace}:*"]
  create_role                  = true
  role_name                    = local.role_name
  provider_url                 = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  role_policy_arns = [
    aws_iam_policy.otel_policy.arn
  ]
  number_of_role_policy_arns = 1
}

output "role_arn" {
  value = module.iam_assumable_role_with_oidc.iam_role_arn
}

output "repository_url" {
  value = aws_ecr_repository.repository.repository_url
}