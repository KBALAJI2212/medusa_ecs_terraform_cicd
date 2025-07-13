variable "private_sub_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/26", "10.0.0.64/26"]
}

variable "public_sub_cidrs" {
  type    = list(string)
  default = ["10.0.0.128/26", "10.0.0.192/26"]
}

variable "availability_zones" {
   type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}


locals {
  medusa_backend_url = "https://${aws_lb.app_lb.dns_name}"
  redis_url = "redis://${aws_elasticache_cluster.medusa_elasticache_redis.cache_nodes[0].address}:6379"
  database_url = "postgres://${aws_db_instance.medusa_rds_postgresql.username}:${data.aws_ssm_parameter.medusa_rds_postgresql_password.value}@${aws_db_instance.medusa_rds_postgresql.endpoint}/${aws_db_instance.medusa_rds_postgresql.db_name}?sslmode=no-verify"
}

data "aws_ssm_parameter" "hosted_zone_cert_arn" {
  name = "/roboshop/hosted_zone_cert_arn"
}
data "aws_ssm_parameter" "medusa_rds_postgresql_password" {
  name            = "/medusa/medusa_rds_postgresql_password"
  with_decryption = true
}

output "rds_endpoint" {
  value = aws_db_instance.medusa_rds_postgresql.endpoint
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.medusa_elasticache_redis.cache_nodes[0].address
}

