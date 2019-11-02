variable "table_name" {
  type = "string"
}

variable "hash_key" {
  type = "string"
}

variable "attributes" {
}

variable "range_key" {
  type    = "string"
  default = null
}

variable "stream_view_type" {
  default = null
}

variable "ttl_attribute" {
  default = null
}

variable "max_capacity" {
  default = 3000
}

resource "aws_dynamodb_table" "table" {
  name           = var.table_name
  read_capacity  = 2
  write_capacity = 2
  hash_key       = var.hash_key
  range_key      = var.range_key

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  server_side_encryption {
    enabled = true
  }

  stream_enabled   = var.stream_view_type == null ? false : true
  stream_view_type = var.stream_view_type

  lifecycle {
    ignore_changes = ["read_capacity", "write_capacity"]
  }


  dynamic "ttl" {
    for_each = var.ttl_attribute == null ? [] : list(var.ttl_attribute)
    content {
      attribute_name = ttl.value.name
      enabled = true
    }
  }
}

data "aws_iam_policy_document" "scale_policy_doc" {
  statement {
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:UpdateTable",
    ]

    resources = [
      aws_dynamodb_table.table.arn,
    ]
  }

  statement {
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:SetAlarmState",
      "cloudwatch:DeleteAlarms",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_appautoscaling_target" "read_target" {
  max_capacity       = var.max_capacity
  min_capacity       = 2
  resource_id        = format("table/%s", aws_dynamodb_table.table.id)
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "ready_polciy" {
  name               = format("DynamoDBReadCapacityUtilization:%s", aws_appautoscaling_target.read_target.resource_id)
  policy_type        = "TargetTrackingScaling"
  resource_id        = "${aws_appautoscaling_target.read_target.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.read_target.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.read_target.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_target" "write_target" {
  max_capacity       = var.max_capacity
  min_capacity       = 2
  resource_id        = format("table/%s", aws_dynamodb_table.table.id)
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "write_policy" {
  name               = format("DynamoDBWriteCapacityUtilization:%s", aws_appautoscaling_target.write_target.resource_id)
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write_target.resource_id
  scalable_dimension = aws_appautoscaling_target.write_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.write_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

output "id" {
  value = aws_dynamodb_table.table.id
}

output "arn" {
  value = aws_dynamodb_table.table.arn
}

output "stream_arn" {
  value = aws_dynamodb_table.table.stream_arn
}
