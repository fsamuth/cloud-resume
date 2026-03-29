resource "aws_apigatewayv2_api" "visitor_counter" {
  name          = "${var.project_name}-api-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "visitor_counter" {
  api_id           = aws_apigatewayv2_api.visitor_counter.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_counter.invoke_arn
}

resource "aws_apigatewayv2_route" "resume_visitor_count" {
  api_id    = aws_apigatewayv2_api.visitor_counter.id
  route_key = "GET /count"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_counter.id}"
}

resource "aws_apigatewayv2_stage" "visitor_counter" {
  api_id      = aws_apigatewayv2_api.visitor_counter.id
  name        = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      sourceIp         = "$context.identity.sourceIp"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }
  default_route_settings {
    throttling_rate_limit  = 100 # requests per second
    throttling_burst_limit = 50  # max concurrent requests
  }

}

resource "aws_lambda_permission" "visitor_counter" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_counter.execution_arn}/*/*"
}