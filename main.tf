provider "aws" {
  region = "ap-southeast-2"
}


resource "aws_budgets_budget" "budget_limit" {
  name              = "monthlybudget"
  limit_amount      = var.budget_limit_amount
  limit_unit        = "USD"
  time_period_start = "2023-09-01_00:00"
  time_period_end   = "2087-06-15_00:00"
  time_unit         = "MONTHLY"
  budget_type       = "COST"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.email_address]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.email_address]
  }
}

data "aws_organizations_organization" "org" {}

data "aws_organizations_organizational_units" "ou" {
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

resource "aws_budgets_budget_action" "cclBudgetActiondeny" {
  budget_name       = aws_budgets_budget.budget_limit.name
  action_type       = "APPLY_SCP_POLICY"
  approval_model    = "MANUAL"
  notification_type = "ACTUAL"

  action_threshold {
    action_threshold_value = 100
    action_threshold_type  = "PERCENTAGE"
  }

  definition {
    scp_action_definition {
      policy_id  = aws_organizations_policy.denyall_scp.id
      target_ids = [for ou in data.aws_organizations_organizational_units.ou.children : ou.id]
    }
  }

  execution_role_arn = aws_iam_role.budget_SCP_role.arn

  subscriber {
    subscription_type = "EMAIL"
    address           = var.email_address
  }
}

resource "aws_organizations_policy" "denyall_scp" {
  name        = "denyall_scp"
  description = "SCP that denies all AWS resource creation actions"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DenyAllActions",
        "Effect": "Deny",
        "Action": [
          "ec2:RunInstances",
          "s3:CreateBucket",
          "rds:CreateDBInstance",
          "lambda:CreateFunction",
          "dynamodb:CreateTable",
          "sqs:CreateQueue",
          "kinesis:CreateStream",
          "redshift:CreateCluster",
          "glue:CreateDatabase",
          "emr:RunJobFlow",
          "ecs:CreateCluster",
          "elasticache:CreateCacheCluster",
          "elasticloadbalancing:CreateLoadBalancer"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role" "budget_SCP_role" {
  name = "budget_SCP2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "budgets.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "SCP_Permissions_Policy"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "organizations:ListPolicies",
            "organizations:CreatePolicy",
            "organizations:AttachPolicy",
            "organizations:DetachPolicy",
            "organizations:DeletePolicy",
            "organizations:UpdatePolicy",
          ],
          Effect   = "Allow",
          Resource = "*",
        },
      ],
    })
  }
}

