variable "role" {
  type = string
}

variable "policy_arn" {
  type = string
}

resource "aws_iam_role_policy_attachment" "role_attatchment" {
  role       = var.role
  policy_arn = var.policy_arn
}

output "name" {
  depends_on = [aws_iam_role_policy_attachment.role_attatchment]
  value      = var.role
}
