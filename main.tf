locals {
  app_name_and_env = "${var.app_name}-${local.app_env}"
  app_env          = var.app_env

  db_password = random_password.db_root.result

  account = data.aws_caller_identity.this.account_id
  region  = data.aws_region.current.name
}

/*
 * Create user for CI/CD to perform ECS actions
 */
resource "aws_iam_user" "cd" {
  count = var.create_cd_user ? 1 : 0

  name = "cd-${local.app_name_and_env}"
}

resource "aws_iam_access_key" "cd" {
  count = var.create_cd_user ? 1 : 0

  user = aws_iam_user.cd[0].name
}

resource "aws_iam_user_policy" "cd" {
  count = var.create_cd_user ? 1 : 0

  name = "ecs_deployment"
  user = aws_iam_user.cd[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:RegisterTaskDefinition",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
        ]
        Resource = "arn:aws:ecs:*:${local.account}:service/${module.ecsasg.ecs_cluster_name}/${module.ecs.service_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:StopTask",
        ]
        Resource = "arn:aws:ecs:*:${local.account}:task/${module.ecsasg.ecs_cluster_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ListTasks",
        ]
        "Condition" : {
          "ArnEquals" : {
            "ecs:cluster" : "arn:aws:ecs:*:${local.account}:cluster/${module.ecsasg.ecs_cluster_name}"
          }
        }
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:StartTask",
        ]
        Resource = "arn:aws:ecs:*:${local.account}:task-definition/${module.ecs.task_def_family}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
        ]
        Resource = module.ecsasg.ecsServiceRole_arn
      },
    ]
  })
}

/*
 * Create Cloudwatch log group
 */
resource "aws_cloudwatch_log_group" "logs" {
  name              = local.app_name_and_env
  retention_in_days = var.log_retention_in_days
}

/*
 * Create target group for ALB
 */
resource "aws_alb_target_group" "tg" {
  name                 = substr("tg-${local.app_name_and_env}", 0, 32)
  port                 = "80"
  protocol             = "HTTP"
  vpc_id               = module.vpc.id
  deregistration_delay = "30"

  stickiness {
    type = "lb_cookie"
  }

  dynamic "health_check" {
    for_each = [var.health_check]
    content {
      enabled             = try(health_check.value.enabled, null)
      healthy_threshold   = try(health_check.value.healthy_threshold, null)
      interval            = try(health_check.value.interval, null)
      matcher             = try(health_check.value.matcher, null)
      path                = try(health_check.value.path, null)
      port                = try(health_check.value.port, null)
      protocol            = try(health_check.value.protocol, null)
      timeout             = try(health_check.value.timeout, null)
      unhealthy_threshold = try(health_check.value.unhealthy_threshold, null)
    }
  }
}

/*
 * Create listener rule for hostname routing to new target group
 */
resource "aws_alb_listener_rule" "tg" {
  listener_arn = module.alb.https_listener_arn
  priority     = "218"

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.tg.arn
  }

  condition {
    host_header {
      values = ["${var.subdomain}.${var.domain_name}"]
    }
  }
}

/*
 *  Create cloudwatch dashboard for service
 */
module "ecs-service-cloudwatch-dashboard" {
  count = var.create_dashboard ? 1 : 0

  source  = "silinternational/ecs-service-cloudwatch-dashboard/aws"
  version = "~> 3.1"

  cluster_name   = module.ecsasg.ecs_cluster_name
  dashboard_name = "${local.app_name_and_env}-${local.region}"
  service_names  = [var.app_name]
}

/*
 * Create RDS root password
 */
resource "random_password" "db_root" {
  length = 16

  # this list is the same as the default list with only '@' removed
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

/*
 * Create an RDS database
 */
resource "aws_db_instance" "this" {
  apply_immediately           = false
  auto_minor_version_upgrade  = var.database_auto_minor_version_upgrade
  allow_major_version_upgrade = var.database_allow_major_version_upgrade
  engine                      = "mariadb"
  engine_version              = var.database_engine_version
  allocated_storage           = "20" // 20 gibibyte
  copy_tags_to_snapshot       = true
  ca_cert_identifier          = var.rds_ca_cert_identifier
  instance_class              = var.database_instance_class
  db_name                     = var.database_name
  identifier                  = "${var.app_name}-${var.app_env}"
  username                    = var.database_user
  password                    = local.db_password
  db_subnet_group_name        = module.vpc.db_subnet_group_name
  storage_type                = "gp2"
  storage_encrypted           = var.database_storage_encrypted
  backup_retention_period     = "14"
  multi_az                    = var.database_multi_az
  publicly_accessible         = false
  vpc_security_group_ids      = [module.vpc.vpc_default_sg_id]
  skip_final_snapshot         = true
  deletion_protection         = var.database_deletion_protection
  parameter_group_name        = var.database_parameter_group_name

  tags = {
    Name     = "${var.app_name}-${var.app_env}"
    app_name = var.app_name
    app_env  = var.app_env
  }
}

/*
 * Optional Adminer database manager
 */
module "adminer" {
  count   = var.create_adminer ? 1 : 0
  source  = "silinternational/adminer/aws"
  version = "~> 1.1"

  adminer_default_server = aws_db_instance.this.address
  app_name               = var.app_name
  app_env                = var.app_env
  vpc_id                 = module.vpc.id
  alb_https_listener_arn = module.alb.https_listener_arn
  subdomain              = "adminer-${local.app_name_and_env}"
  cloudflare_domain      = var.domain_name
  ecs_cluster_id         = module.ecsasg.ecs_cluster_id
  ecsServiceRole_arn     = module.ecsasg.ecsServiceRole_arn
  alb_dns_name           = module.alb.dns_name
  enable                 = var.enable_adminer
}

/*
 * Create new ecs service
 */
module "ecs" {
  source             = "github.com/silinternational/terraform-modules//aws/ecs/service-only?ref=8.13.3"
  cluster_id         = module.ecsasg.ecs_cluster_id
  service_name       = var.app_name
  service_env        = local.app_env
  container_def_json = var.container_def_json
  desired_count      = var.desired_count
  tg_arn             = aws_alb_target_group.tg.arn
  lb_container_name  = "hub"
  lb_container_port  = "80"
  ecsServiceRole_arn = module.ecsasg.ecsServiceRole_arn
}

/*
 * Create Cloudflare DNS record
 */
resource "cloudflare_record" "dns" {
  count = var.create_dns_record ? 1 : 0

  zone_id         = data.cloudflare_zone.this.id
  name            = var.subdomain
  value           = module.alb.dns_name
  type            = "CNAME"
  proxied         = true
  allow_overwrite = var.dns_allow_overwrite
}

data "cloudflare_zone" "this" {
  name = var.domain_name
}


/*
 * AWS data
 */

data "aws_caller_identity" "this" {}

data "aws_region" "current" {}
