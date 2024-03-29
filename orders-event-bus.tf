resource "aws_cloudwatch_event_bus" "orders_bus" {
  name = "orders"
}

resource "aws_cloudwatch_event_connection" "carrier_connection" {
  name               = "carrier"
  authorization_type = "BASIC"

  auth_parameters {
    basic {
      username = "user"
      password = "Pass1234!"
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "carrier_api_destination" {
  name                             = "carrier-api-destination"
  invocation_endpoint              = "${module.carrier-mock-function.lambda_function_url}/orders"
  http_method                      = "POST"
  invocation_rate_limit_per_second = 20
  connection_arn                   = aws_cloudwatch_event_connection.carrier_connection.arn
}

resource "aws_cloudwatch_event_rule" "create_orders_rule" {
  name           = "order-created"
  event_bus_name = aws_cloudwatch_event_bus.orders_bus.name

  event_pattern = jsonencode({
    source = ["dynamodb.orders"]
    detail = {
      eventName = ["INSERT"]
    }
  })
}

resource "aws_iam_role" "carrier_api_destination_role" {
  name = "EventBridgeApiDestinationCarrierRole"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Effect" = "Allow"
        "Principal" = {
          "Service" = "events.amazonaws.com"
        },
        "Action" = "sts:AssumeRole"
      }
    ]
  })
  inline_policy {
    name = "AllowApiDestinationsInvoke"
    policy = jsonencode({
      Statement = {
        Effect = "Allow",
        Action = [
          "events:InvokeApiDestination"
        ],
        Resource = [aws_cloudwatch_event_api_destination.carrier_api_destination.arn]
      }
    })
  }
}

resource "aws_cloudwatch_event_target" "carrie_api_destination" {
  event_bus_name = aws_cloudwatch_event_bus.orders_bus.name
  rule           = aws_cloudwatch_event_rule.create_orders_rule.name
  arn            = aws_cloudwatch_event_api_destination.carrier_api_destination.arn
  role_arn       = aws_iam_role.carrier_api_destination_role.arn
  input_transformer {
    input_template = "{\"order_id\" : \"<order_id>\", \"state\" : \"<state>\"}"
    input_paths = {
      order_id = "$.detail.order.id"
      state = "$.detail.order.state"
    }
  }
}

resource "aws_cloudwatch_event_rule" "order_shipped_rule" {
  name           = "order-shipped"
  event_bus_name = aws_cloudwatch_event_bus.orders_bus.name

  event_pattern = jsonencode({
    source = ["carrier"]
    "detail-type" = ["carrier.order_shipped"]
  })
}


resource "aws_cloudwatch_event_target" "confirm_shipment_function" {
  event_bus_name = aws_cloudwatch_event_bus.orders_bus.name
  rule           = aws_cloudwatch_event_rule.order_shipped_rule.name
  arn            = module.confirm-shipment-function.lambda_function_arn
  input_transformer {
    input_template = "{\"order_id\" : \"<order_id>\", \"shipped_at\" : \"<shipped_at>\"}"
    input_paths = {
      order_id = "$.detail.order_id"
      shipped_at = "$.detail.shipped_at"
    }
  }
}