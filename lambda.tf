resource "aws_lambda_function" "remove-scppolicy" {
  filename         = "${path.module}/python/remove-scppolicy.zip"
  function_name    = "remove-scppolicy-function"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "remove-scppolicy.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60
  source_code_hash = filebase64sha256("${path.module}/python/remove-scppolicy.zip")
  environment {
    variables = {
      policy_id  = aws_organizations_policy.denyall_scp.id,
      target_ids = jsonencode([for ou in data.aws_organizations_organizational_units.ou.children : ou.id])
    }
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "remove_scp_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "inline_scp_removal_policy" {
  name        = "inline_scp_removal_policy"
  description = "IAM policy for Lambda execution with SCP removal permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = "*",
      },
      {
        Effect   = "Allow",
        Action   = "lambda:*",
        Resource = "*",
      },
      {
        Effect = "Allow",
        Action = [
          "organizations:RemovePolicyFromTarget",
          "organizations:ListPoliciesForTarget",
          "organizations:ListTargetsForPolicy",
          "organizations:DetachPolicy",
        ],
        Resource = "*",
      },
    ],
  })
}

resource "aws_iam_policy_attachment" "lambda_inline_policy_attachment" {
  name       = "scp_removal"
  policy_arn = aws_iam_policy.inline_scp_removal_policy.arn
  roles      = [aws_iam_role.lambda_execution_role.name]
}

data "archive_file" "zip_the_python_code" {
  type        = "zip"
  output_path = "${path.module}/python/remove-scppolicy.zip"
  source_file = "${path.module}/python/remove-scppolicy.py"
}

resource "aws_cloudwatch_event_rule" "every_month_start" {
  name                = "every_month_start"
  schedule_expression = "cron(0 0 1 * ? *)"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remove-scppolicy.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_month_start.arn
}

resource "aws_cloudwatch_event_target" "remove_scp_policy_target" {
  rule      = aws_cloudwatch_event_rule.every_month_start.name
  target_id = "remove_scp_policy_target"
  arn       = aws_lambda_function.remove-scppolicy.arn
}