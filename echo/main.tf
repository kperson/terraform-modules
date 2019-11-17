variable "in" {
  type = list(string)
}

variable "out" {
  type = string
}

output "out" {
  value = var.out
}

