resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = {
    Name = "${var.name_prefix}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "archive_file" "alert_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/alert_handler.py"
  output_path = "${path.module}/.build/alert_handler.zip"
}

resource "aws_lambda_function" "alert_handler" {
  function_name    = "${var.name_prefix}-alert-handler"
  role             = var.lambda_role_arn
  handler          = "alert_handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.alert_lambda.output_path
  source_code_hash = data.archive_file.alert_lambda.output_base64sha256
  timeout          = 15
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
      WEBHOOK_URL = var.alert_webhook_url
    }
  }

  tags = {
    Name = "${var.name_prefix}-alert-handler"
  }
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert_handler.arn
}
