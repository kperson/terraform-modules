variable "lambda_arn" {
  type = "string"
}

variable "api_id" {
  type = "string"
}

variable "api_root_resource_id" {
  type = "string"
}

variable "authorization" {
  type    = "string"
  default = "NONE"
}

variable "authorizer_id" {
  type    = "string"
  default = null
}

variable "api_key_required" {
  type    = "string"
  default = null
}

variable "authorization_scopes" {
  type    = "list"
  default = null
}

variable "stage_name" {
  type = "string"
  default = null
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = var.api_id
  parent_id   = var.api_root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "api" {
  rest_api_id          = var.api_id
  resource_id          = aws_api_gateway_resource.api.id
  http_method          = "ANY"
  authorization        = var.authorization
  authorizer_id        = var.authorizer_id
  api_key_required     = var.api_key_required
  authorization_scopes = var.authorization_scopes
}

resource "aws_api_gateway_integration" "api" {
  rest_api_id             = var.api_id
  resource_id             = aws_api_gateway_resource.api.id
  http_method             = aws_api_gateway_method.api.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.lambda_arn}/invocations"
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.api_id}/*/*/*"
}

resource "aws_api_gateway_deployment" "api" {
  depends_on  = ["aws_api_gateway_integration.api"]
  rest_api_id = var.api_id
  stage_name  = var.stage_name
}


data "template_file" "stage" {
  depends_on = [
    aws_api_gateway_deployment.api
  ]
  template = "$${stage}"

  vars = {
    stage = var.stage_name
  }
}

output "stage" {
  value = data.template_file.stage.rendered
}
