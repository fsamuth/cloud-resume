resource "aws_apigatewayv2_api" "resume_api_gateway" {
  name          = "${var.project_name}-api-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "resume_api_gateway" {
  api_id           = aws_apigatewayv2_api.resume_api_gateway.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_counter.invoke_arn
}

resource "aws_apigatewayv2_route" "resume_visitor_count" {
  api_id    = aws_apigatewayv2_api.resume_api_gateway.id
  route_key = "GET /count"
  target    = "integrations/${aws_apigatewayv2_integration.resume_api_gateway.id}"
}

resource "aws_apigatewayv2_stage" "resume_api_gateway" {
  api_id      = aws_apigatewayv2_api.resume_api_gateway.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "visitor_counter" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_api_gateway.execution_arn}/*/*"
}