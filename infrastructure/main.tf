#VPC
resource "aws_vpc" "medusa_vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "medusa_vpc"
  }
}
resource "aws_internet_gateway" "medusa_igw" {

  vpc_id = aws_vpc.medusa_vpc.id

  tags = {
    Name = "medusa_internet_gateway"
  }
}
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}
resource "aws_nat_gateway" "medusa_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  depends_on = [aws_eip.nat_eip]
}

#Subnets
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.medusa_vpc.id
  cidr_block              = var.public_sub_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "medusa_public_subnet_${count.index + 1}"
  }
}
resource "aws_subnet" "private_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.medusa_vpc.id
  cidr_block              = var.private_sub_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "medusa_private_subnet_${count.index + 1}"
  }
}


#Security Groups
resource "aws_security_group" "public_sg" {
  name        = "public_sg"
  description = "SG for instances in Public Subnet."
  vpc_id      = aws_vpc.medusa_vpc.id
  egress      = []
  revoke_rules_on_delete = false

  tags = {
    Name = "medusa_public_security_group"
  }
}
resource "aws_vpc_security_group_ingress_rule" "https_from_internet_to_public_sg" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow inbound HTTPS from internet"
}
resource "aws_vpc_security_group_ingress_rule" "http_from_internet_to_public_sg" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow inbound HTTP from internet"
}
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs_9000" {
  security_group_id            = aws_security_group.public_sg.id
  referenced_security_group_id = aws_security_group.private_sg.id
  from_port                    = 9000
  to_port                      = 9000
  ip_protocol                  = "tcp"
  description                  = "Allows ALB requests to ECS on port 9000"
}

resource "aws_security_group" "private_sg" {
  name        = "private_sg"
  description = "SG for instances in Private Subnet."
  vpc_id      = aws_vpc.medusa_vpc.id
  egress      = []
  revoke_rules_on_delete = false

  tags = {
    Name = "medusa_private_security_group"
  }
}
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_9000" {
  security_group_id            = aws_security_group.private_sg.id
  referenced_security_group_id = aws_security_group.public_sg.id
  from_port                    = 9000
  to_port                      = 9000
  ip_protocol                  = "tcp"
  description                  = "ECS receives traffic from ALB on port 9000"
}
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs_private" {
  security_group_id            = aws_security_group.private_sg.id
  referenced_security_group_id = aws_security_group.private_sg.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow ECS to talk to RDS in private_sg"
}
resource "aws_vpc_security_group_ingress_rule" "redis_from_ecs_private" {
  security_group_id            = aws_security_group.private_sg.id
  referenced_security_group_id = aws_security_group.private_sg.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Allow ECS to talk to Redis in private_sg"
}
resource "aws_vpc_security_group_egress_rule" "to_nat_from_private_sg" {

  security_group_id            = aws_security_group.private_sg.id
  cidr_ipv4                    = "0.0.0.0/0"
  ip_protocol                  = "-1"
  description                  = "Allows outbound connections to internet via NAT gateway"
}


#Routes

####PUBLIC SUBNETS ROUTES
resource "aws_route_table" "public_subnet_rt" {
  vpc_id = aws_vpc.medusa_vpc.id

  route {
    cidr_block = "10.0.0.0/24"
    gateway_id = "local"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.medusa_igw.id
  }

  tags = {
    Name = "medusa_public_subnet_routetable"
  }
}
resource "aws_route_table_association" "public_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_subnet_rt.id
}

####PRIVATE SUBNETS ROUTES
resource "aws_route_table" "private_subnet_rt" {
  vpc_id = aws_vpc.medusa_vpc.id

  route {
    cidr_block = "10.0.0.0/24"
    gateway_id = "local"
  }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.medusa_nat.id
  }

  tags = {
    Name = "medusa_private_subnet_routetable"
  }
}
resource "aws_route_table_association" "private_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.private_subnet[count.index].id  
  route_table_id = aws_route_table.private_subnet_rt.id
}


#Load Balancer
resource "aws_s3_bucket" "load_balancer_logs_bucket" {
  bucket        = "load-balancer-logs5"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "load_balancer_logs_bucket_policy" {
  bucket = aws_s3_bucket.load_balancer_logs_bucket.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::127311923021:root"
        },
        "Action" : "s3:*",
        "Resource" : [
          "arn:aws:s3:::load-balancer-logs5",
          "arn:aws:s3:::load-balancer-logs5/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "delivery.logs.amazonaws.com"
        },
        "Action" : "s3:*",
        "Resource" : [
          "arn:aws:s3:::load-balancer-logs5",
          "arn:aws:s3:::load-balancer-logs5/*"
        ],
        "Condition" : {
          "StringEquals" : {
            "s3:x-amz-acl" : "bucket-owner-full-control"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "delivery.logs.amazonaws.com"
        },
        "Action" : "s3:GetBucketAcl",
        "Resource" : "arn:aws:s3:::load-balancer-logs5"
      }
    ]
  })
}

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  load_balancer_type = "application"
  subnets = [aws_subnet.public_subnet[0].id,aws_subnet.public_subnet[1].id]
  security_groups    = [aws_security_group.public_sg.id]
  internal           = false

  access_logs {
    bucket  = "load-balancer-logs5"
    enabled = true
    prefix  = "app_lb_logs"
  }

  depends_on = [aws_s3_bucket.load_balancer_logs_bucket]

  tags = {
    Name = "medusa_app_load_balancer"
  }
  }
  resource "aws_lb_listener" "app_lb_https_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  certificate_arn = data.aws_ssm_parameter.hosted_zone_cert_arn.value

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.medusa_server_tg.arn
  }

  tags = {
    Name = "app_lb_https_listener"
  }
}
resource "aws_lb_listener" "app_lb_http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name = "app_lb_http_listener"
  }
}
resource "aws_lb_target_group" "medusa_server_tg" {

  name     = "medusa-server-target-group"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.medusa_vpc.id
  target_type = "ip"

  health_check {
    path                = "/app"
    protocol            = "HTTP"
    matcher             = "200-299"
    port                = 9000
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "medusa_server_target_group"
  }

}
resource "aws_route53_record" "record" {
  zone_id = "Z04307862A5Z0E82KA5RX"
  name    = "medusa.balaji.website"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}


#Databases
resource "aws_db_subnet_group" "medusa_postgres_subnet_group" {
  name       = "medusa-postgres-subnet-group"
  subnet_ids = [aws_subnet.private_subnet[0].id,aws_subnet.private_subnet[1].id]
}
resource "aws_db_instance" "medusa_rds_postgresql" {
  allocated_storage    = 10
  db_name              = "medusa_rds_postgresql"
  identifier           = "medusa-postgres"
  engine               = "postgres"
  engine_version       = "17.2"
  instance_class       = "db.t3.micro"
  username             = "balaji"
  password             = data.aws_ssm_parameter.medusa_rds_postgresql_password.value
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  db_subnet_group_name = aws_db_subnet_group.medusa_postgres_subnet_group.name
  skip_final_snapshot  = true
}
resource "aws_elasticache_subnet_group" "medusa_redis_subnet_group" {
  name       = "medusa-redis-subnet-group"
  subnet_ids = [aws_subnet.private_subnet[0].id,aws_subnet.private_subnet[1].id]

  tags = {
    Name = "medusa_redis_subnet_group"
  }
}
resource "aws_elasticache_cluster" "medusa_elasticache_redis" {
  cluster_id           = "medusa-elasticache-redis"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.medusa_redis_subnet_group.name
  security_group_ids   = [aws_security_group.private_sg.id]
}


#ECS cluster for medusa
resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
}
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "ecs_task_execution_role"
  }
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_task_definition" "medusa_server" {
  family                   = "medusa-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048" #Using 2gb ram as mentioned in Medusa docs
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "medusa-server",
      image = "612443913962.dkr.ecr.us-east-1.amazonaws.com/projects:medusa-backend-v1", #My image
      essential = true,
      portMappings = [
        {
          containerPort = 9000,
          protocol      = "tcp"
        }
      ],
      environment = [
      { name = "DATABASE_URL", value = local.database_url },
      { name = "REDIS_URL", value = local.redis_url },
      { name = "ADMIN_CORS", value = local.medusa_backend_url },
      { name = "AUTH_CORS", value = local.medusa_backend_url },
      { name = "MEDUSA_BACKEND_URL", value = local.medusa_backend_url },
      { name = "DISABLE_MEDUSA_ADMIN", value = "false" },
      { name = "MEDUSA_WORKER_MODE", value = "server" },
      ],

      logConfiguration = {
        logDriver = "awslogs"
        options = {
        awslogs-group         = "/ecs/medusa"     
        awslogs-region        = "us-east-1"    
        awslogs-stream-prefix = "ecs-medusa-server"              
      }
      }
    }
  ])
}
resource "aws_ecs_task_definition" "medusa_worker" {
  family                   = "medusa-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048" #Using 2gb ram as mentioned in Medusa docs
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "medusa-worker",
      image = "612443913962.dkr.ecr.us-east-1.amazonaws.com/projects:medusa-backend-v1", #My image
      essential = true,
      portMappings = [
        {
          containerPort = 9000,
          protocol      = "tcp"
        }
      ],
      environment = [
      { name = "DATABASE_URL", value = local.database_url },
      { name = "REDIS_URL", value = local.redis_url },
      { name = "DISABLE_MEDUSA_ADMIN", value = "true" },
      { name = "MEDUSA_WORKER_MODE", value = "worker" },
      ],

      logConfiguration = {
        logDriver = "awslogs"
        options = {
        awslogs-group         = "/ecs/medusa"     
        awslogs-region        = "us-east-1"    
        awslogs-stream-prefix = "ecs-medusa-worker"              
      }
      }
    }
  ])
}
resource "aws_cloudwatch_log_group" "ecs_medusa" {
  name              = "/ecs/medusa"
  retention_in_days = 7  
}

resource "aws_ecs_service" "medusa_server" {
  name            = "medusa-server"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.medusa_server.arn
  desired_count   = 1

  network_configuration {
    subnets = [aws_subnet.private_subnet[0].id,aws_subnet.private_subnet[1].id]
    security_groups = [aws_security_group.private_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.medusa_server_tg.arn
    container_name   = "medusa-server"
    container_port   = 9000
  }

  depends_on = [aws_lb_listener.app_lb_https_listener]
}
resource "aws_ecs_service" "medusa_worker" {
  name            = "medusa-worker"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.medusa_worker.arn
  desired_count   = 1

  network_configuration {
    subnets = [aws_subnet.private_subnet[0].id,aws_subnet.private_subnet[1].id]
    security_groups = [aws_security_group.private_sg.id]
    assign_public_ip = false
  }

  depends_on = [aws_lb_listener.app_lb_https_listener]
}


## Run this once to create Medusa user
#aws ecs run-task --cluster medusa-cluster --launch-type FARGATE --task-definition medusa-server --network-configuration "awsvpcConfiguration={subnets=[subnet-024719900b722fd7b],securityGroups=[sg-0a451f0c6b0bc24f6],assignPublicIp=DISABLED}" --overrides '{"containerOverrides":[{"name":"medusa-server","command":["npx","medusa","user","-e","hi@hello.com","-p","password"]}]}' --count 1 --region us-east-1