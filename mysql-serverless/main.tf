#https://aws.amazon.com/blogs/aws/new-data-api-for-amazon-aurora-serverless/
#https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/data-api.html
#https://www.jeremydaly.com/aurora-serverless-data-api-a-first-look/
#https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_actions-resources-contextkeys.html
#https://docs.aws.amazon.com/rdsdataservice/latest/APIReference/API_Operations.html

variable "database_name" {
  type = "string"
}

variable "db_subnet_group_name" {
  type = "string"
}

variable "kms_key_arn" {
  type = "string"
}

variable "vpc_security_group_ids" {
}

variable "final_snapshot_enabled" {
  default = true
}

variable "seconds_until_auto_pause" {
  default = 1800
}

resource "random_string" "password" {
  length  = 30
  upper   = true
  number  = true
  special = true
}

resource "aws_rds_cluster" "db" {
  master_username           = "dbuser"
  master_password           = "${random_string.password.result}"
  database_name             = "${var.database_name}"
  final_snapshot_identifier = var.final_snapshot_enabled == true ? "${replace(var.database_name, "_", "-")}-final-snapshot" : null
  skip_final_snapshot       = var.final_snapshot_enabled == false
  deletion_protection       = false
  backup_retention_period   = var.final_snapshot_enabled == true ? 5 : 1
  db_subnet_group_name      = "${var.db_subnet_group_name}"
  kms_key_id                = "${var.kms_key_arn}"
  storage_encrypted         = true
  vpc_security_group_ids    = "${var.vpc_security_group_ids}"
  engine                    = "aurora"
  engine_mode               = "serverless"

  scaling_configuration {
    auto_pause               = true
    max_capacity             = 256
    min_capacity             = 2
    seconds_until_auto_pause = ${var.seconds_until_auto_pause}"
    timeout_action           = "ForceApplyCapacityChange"
  }
}

resource "null_resource" "enable_http_endpoint" {
  depends_on = ["aws_rds_cluster.db"]

  provisioner "local-exec" {
    command = "aws rds modify-db-cluster --db-cluster-identifier ${aws_rds_cluster.db.id} --apply-immediately --enable-http-endpoint"

    environment = {
    }
  }
}


locals {
  data_api = {
    username            = "dbuser"
    password            = "${random_string.password.result}"
    engine              = "aurora" //mysql
    host                = "${aws_rds_cluster.db.endpoint}"
    port                = 3306
    dbClusterIdentifier = "${aws_rds_cluster.db.cluster_identifier}"
  }
}

resource "aws_secretsmanager_secret" "data_api" {
  name       = "/db/data_api/${var.database_name}"
  kms_key_id = "${var.kms_key_arn}"
}

resource "aws_secretsmanager_secret_version" "data_api" {
  secret_id     = "${aws_secretsmanager_secret.data_api.id}"
  secret_string = "${jsonencode(local.data_api)}"
}

output "endpoint" {
  value = "${aws_rds_cluster.db.endpoint}"
}

output "reader_endpoint" {
  value = "${aws_rds_cluster.db.reader_endpoint}"
}

output "database_name" {
  value = "${var.database_name}"
}

output "data_api_secret_arn" {
  value = "${aws_secretsmanager_secret.data_api.arn}"
}

output "data_api_secret_id" {
  value = "${aws_secretsmanager_secret.data_api.id}"
}

output "cluster_arn" {
  value = "${aws_rds_cluster.db.arn}"
}