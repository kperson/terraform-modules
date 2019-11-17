variable "in" {
  type = list(string)
}

variable "out" {
  type = string
}

output "out" {
  type  = string
  value = var.out
}

