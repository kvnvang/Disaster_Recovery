# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  provider = aws.primary
  name     = "dr-failover-lambda"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# SSM Automation
resource "aws_iam_role_policy" "lambda_failover_policy" {
  provider = aws.primary
  name = "dr-failover-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:StartAutomationExecution",
          "ssm:GetAutomationExecution",
          "ssm:DescribeAutomationExecutions"
        ]
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda failover handler
resource "aws_lambda_function" "dr_failover_handler" {
  function_name = "dr-failover-handler"
  role = aws_iam_role.lambda_role.arn
  handler = "index.handler"
  runtime = "nodejs18.x"
  filename = "lambda_failover_handler.zip"
  source_code_hash = filebase64sha256("lambda_failover_handler.zip")
  timeout = 30
  memory_size = 256

  environment {
    variables = {
      SSM_DOCUMENT_NAME = aws_ssm_document.dr_failover.name
      SECONDARY_INSTANCE_ID = aws_instance.secondary_instance.id
    }
  }

  tags = {
    Name = "${var.disaster_recovery}-dr-failover-handler"
    Environment = "DisasterRecovery"
  }
}

# SNS to Lambda
resource "aws_sns_topic_subscription" "sns_lambda" {
  provider = aws.primary
  topic_arn = aws_sns_topic.dr_failover_topic.arn
  protocol = "lambda"
  endpoint = aws_lambda_function.dr_failover_handler.arn
}

# SNS invoke Lambda
resource "aws_lambda_permission" "allow_sns" {
  statement_id = "AllowExecutionFromSNS"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dr_failover_handler.function_name
  principal = "sns.amazonaws.com"
  source_arn = aws_sns_topic.dr_failover_topic.arn
}