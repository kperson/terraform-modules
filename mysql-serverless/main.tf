#https://aws.amazon.com/blogs/aws/new-data-api-for-amazon-aurora-serverless/
#https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/data-api.html
#https://www.jeremydaly.com/aurora-serverless-data-api-a-first-look/
#https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_actions-resources-contextkeys.html
#https://docs.aws.amazon.com/rdsdataservice/latest/APIReference/API_Operations.html

variable "database_name" {
  type = string
}

variable "cluster_identifier" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "vpc_security_group_ids" {
}

variable "final_snapshot_enabled" {
  default = true
}

variable "seconds_until_auto_pause" {
  default = 1800
}

resource "random_string" "entropy" {
  length  = 10
  upper   = false
  number  = false
  special = false
}


variable "engine" {
  default = "aurora-mysql"
}

variable "engine_mode" {
  default = "serverless"
}

variable "engine_version" {
  default = "5.7.mysql_aurora.2.07.1"
}

variable "min_capacity" {
  default = 1
}

variable "max_capacity" {
  default = 256
}

resource "aws_rds_cluster" "db" {

  master_username    = "dbuser"
  master_password    = "DEFAULT_PASSWORD"
  database_name      = var.database_name
  cluster_identifier = var.cluster_identifier

  final_snapshot_identifier = var.final_snapshot_enabled == true ? format("%s-final-snapshot-%s", replace(var.database_name, "_", "-"), random_string.entropy.result) : null
  skip_final_snapshot       = var.final_snapshot_enabled == false
  deletion_protection       = false
  backup_retention_period   = var.final_snapshot_enabled == true ? 5 : 1
  db_subnet_group_name      = var.db_subnet_group_name
  kms_key_id                = var.kms_key_arn
  storage_encrypted         = true
  vpc_security_group_ids    = var.vpc_security_group_ids
  engine                    = var.engine
  engine_mode               = var.engine_mode
  engine_version            = var.engine_version
  enable_http_endpoint      = true

  scaling_configuration {
    auto_pause               = true
    max_capacity             = var.max_capacity
    min_capacity             = var.min_capacity
    seconds_until_auto_pause = var.seconds_until_auto_pause
    timeout_action           = "ForceApplyCapacityChange"
  }
}



resource "null_resource" "generate_password" {
  triggers = {
    cluster_identifier = aws_rds_cluster.db.cluster_identifier
  }
  provisioner "local-exec" {

    command = format("echo '%s' > credentials.json", jsonencode({
      username            = "dbuser"
      password            = "MY_PASSWORD_TEMPLATE"
      engine              = var.engine
      host                = aws_rds_cluster.db.endpoint
      port                = 3306
      dbClusterIdentifier = aws_rds_cluster.db.cluster_identifier
    }))
    environment = {
    }
  }
}

resource "null_resource" "change_password_enable_http_data_api" {
  triggers = {
    cluster_identifier = aws_rds_cluster.db.cluster_identifier
  }
  depends_on = [null_resource.generate_password]

  provisioner "local-exec" {

    command = format("%s/setup-password.sh credentials.json /db/data_api/%s-%s %s %s && rm credentials.json", path.module, var.database_name, random_string.entropy.result, var.kms_key_arn, aws_rds_cluster.db.id)
    environment = {
    }
  }
}

output "endpoint" {
  value = aws_rds_cluster.db.endpoint
}

output "reader_endpoint" {
  value = aws_rds_cluster.db.reader_endpoint
}

output "database_name" {
  value = var.database_name
}

data "aws_secretsmanager_secret" "data_api" {
  depends_on = [null_resource.change_password_enable_http_data_api]
  name       = format("/db/data_api/%s-%s", var.database_name, random_string.entropy.result)
}

output "data_api_secret_name" {
  depends_on = [null_resource.change_password_enable_http_data_api]

  value = format("/db/data_api/%s-%s", var.database_name, random_string.entropy.result)
}

output "data_api_secret_arn" {
  value = data.aws_secretsmanager_secret.data_api.arn
}

output "cluster_arn" {
  value = aws_rds_cluster.db.arn
}