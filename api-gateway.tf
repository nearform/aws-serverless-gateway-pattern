locals {
  api_name = "tasks-api"
}
resource "aws_api_gateway_rest_api" "tasks-api" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = local.api_name
      version = "1.0"
    }
    paths = {
      "/" = {
        post = {
          x-amazon-apigateway-integration = {
            httpMethod           = "POST"
            payloadFormatVersion = "1.0"
            type                 = "aws_proxy"
            uri                  = module.create-tasks.lambda_function_qualified_invoke_arn
          }
        }
      }
    }
  })

  name = local.api_name

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.tasks-api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.tasks-api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.tasks-api.id
  stage_name    = "prod"
}

output "tasks_api_gateway_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}