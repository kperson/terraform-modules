variable "table_arn" {
  type = "string"
}

variable "stream_arn" {
  type    = "string"
  default = null
}


data "aws_iam_policy_document" "document" {
  dynamic "statement" {
    for_each = var.stream_arn == null ? [] : list(var.stream_arn)
    content {
      actions = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
      ]

      resources = [
        "${statement.value}"
      ]
    }
  }

  statement {
    actions = [
      "dynamodb:ListStreams",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:BatchGetItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
    ]

    resources = [
      "${var.table_arn}"
    ]
  }
}

resource "aws_iam_policy" "policy" {
  policy = "${data.aws_iam_policy_document.document.json}"
}

output "arn" {
  value = "${aws_iam_policy.policy.arn}"
}
