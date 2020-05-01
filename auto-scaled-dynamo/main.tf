variable "table_name" {
  type = string
}

variable "hash_key" {
  type = string
}

variable "attributes" {
}

variable "range_key" {
  type    = string
  default = null
}

variable "stream_view_type" {
  default = null
}

variable "ttl_attribute" {
  default = null
}

variable "billing_mode" {
  default = "PROVISIONED"
}

variable "global_secondary_indices" {
  type = list(object({
    name      = string
    hash_key  = string
    range_key = string
  }))
  default = []
}

variable "local_secondary_indices" {
  type = list(object({
    name      = string
    range_key = string
  }))
  default = []
}

variable "max_capacity" {
  default = 3000
}

variable "min_capacity" {
  default = 1
}

resource "aws_dynamodb_table" "table" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  read_capacity  = 1
  write_capacity = 1
  hash_key       = var.hash_key
  range_key      = var.range_key

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }


  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indices
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      read_capacity   = 1
      write_capacity  = 1
      projection_type = "ALL"
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indices
    content {
      name            = local_secondary_index.value.name
      range_key       = local_secondary_index.value.range_key
      projection_type = "ALL"
    }
  }

  server_side_encryption {
    enabled = true
  }

  stream_enabled   = var.stream_view_type == null ? false : true
  stream_view_type = var.stream_view_type

  lifecycle {
    ignore_changes = [read_capacity, write_capacity]
  }


  dynamic "ttl" {
    for_each = var.ttl_attribute == null ? [] : list(var.ttl_attribute)
    content {
      attribute_name = ttl.value.name
      enabled        = true
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
  count              = var.billing_mode == "PROVISIONED" ? 1 : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = format("table/%s", aws_dynamodb_table.table.id)
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "ready_polciy" {
  count = var.billing_mode == "PROVISIONED" ? 1 : 0

  name               = format("DynamoDBReadCapacityUtilization:%s", aws_appautoscaling_target.read_target[0].resource_id)
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.read_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read_target[0].service_namespace

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
  count = var.billing_mode == "PROVISIONED" ? 1 : 0

  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = format("table/%s", aws_dynamodb_table.table.id)
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "write_policy" {
  count = var.billing_mode == "PROVISIONED" ? 1 : 0

  name               = format("DynamoDBWriteCapacityUtilization:%s", aws_appautoscaling_target.write_target[0].resource_id)
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.write_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_target" "dynamodb_index_read_target" {

  count              = var.billing_mode == "PROVISIONED" ? length(var.global_secondary_indices) : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = format("table/%s/index/%s", aws_dynamodb_table.table.id, var.global_secondary_indices[count.index].name)
  scalable_dimension = "dynamodb:index:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_index_read_policy" {
  depends_on         = [aws_appautoscaling_target.dynamodb_index_read_target]
  count              = var.billing_mode == "PROVISIONED" ? length(var.global_secondary_indices) : 0
  name               = format("DynamoDBReadCapacityUtilization:Index_%s", var.global_secondary_indices[count.index].name)
  policy_type        = "TargetTrackingScaling"
  resource_id        = format("table/%s/index/%s", aws_dynamodb_table.table.id, var.global_secondary_indices[count.index].name)
  scalable_dimension = "dynamodb:index:ReadCapacityUnits"
  service_namespace  = "dynamodb"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_target" "dynamodb_index_write_target" {
  count              = var.billing_mode == "PROVISIONED" ? length(var.global_secondary_indices) : 0
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = format("table/%s/index/%s", aws_dynamodb_table.table.id, var.global_secondary_indices[count.index].name)
  scalable_dimension = "dynamodb:index:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_index_write_policy" {
  depends_on         = [aws_appautoscaling_target.dynamodb_index_write_target]
  count              = var.billing_mode == "PROVISIONED" ? length(var.global_secondary_indices) : 0
  name               = format("DynamoDBReadCapacityUtilization:Index_%s", var.global_secondary_indices[count.index].name)
  policy_type        = "TargetTrackingScaling"
  resource_id        = format("table/%s/index/%s", aws_dynamodb_table.table.id, var.global_secondary_indices[count.index].name)
  scalable_dimension = "dynamodb:index:WriteCapacityUnits"
  service_namespace  = "dynamodb"

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
