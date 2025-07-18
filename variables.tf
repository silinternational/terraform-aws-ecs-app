
/*
 * App configuration
 */

variable "app_env" {
  description = "The abbreviated version of the environment used for naming resources, typically either stg or prod"
  type        = string
}

variable "app_name" {
  description = "A name to be used, combined with \"app_env\", for naming resources. Should be unique in the AWS account."
  type        = string
}


/*
 * IAM configuration
 */

variable "create_cd_user" {
  description = "Set to true to create an IAM user with permissions for continuous deployment"
  default     = false
  type        = bool
}


/*
 * Cloudwatch configuration
 */

variable "create_dashboard" {
  description = "Set to false to skip creation of a CloudWatch dashboard"
  default     = true
  type        = bool
}

variable "log_retention_in_days" {
  description = "Number of days to retain CloudWatch application logs"
  default     = 30
  type        = number
}


/*
 * DNS configuration
 */

variable "create_dns_record" {
  description = "Set to false to skip creation of a Cloudflare DNS record"
  default     = true
  type        = bool
}

variable "dns_allow_overwrite" {
  description = "Controls whether this module can overwrite an existing DNS record with the same name. Can be used in a multiregion DNS-based failover configuration."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name on which to host the app. Combined with \"subdomain\" to create an ALB listener rule. Also used for the optional DNS record."
  type        = string
}

variable "subdomain" {
  description = "The subdomain on which to host the app. Combined with \"domain_name\" to create an ALB listener rule. Also used for the optional DNS record."
  type        = string
}


/*
 * EC2 configuration
 */

variable "enable_ec2_detailed_monitoring" {
  description = "Enables/disables detailed monitoring for EC2 instances"
  type        = bool
  default     = true
}


/*
 * ECS configuration
 */

variable "container_def_json" {
  description = "The ECS container task definition json"
  type        = string
}

variable "desired_count" {
  description = "The ECS service \"desired_count\" value"
  default     = 2
  type        = number
}


/*
 * ASG configuration
 */

variable "alarm_actions_enabled" {
  description = "Set to true to enable auto-scaling events and actions"
  default     = false
  type        = bool
}

variable "asg_min_size" {
  description = "The minimum size of the Autoscaling Group"
  default     = 1
  type        = number
}

variable "asg_max_size" {
  description = "The maximum size of the Autoscaling Group"
  default     = 5
  type        = number
}

variable "asg_tags" {
  description = "Tags to assign to the Autoscaling Group and EC2 instances"
  default     = {}
  type        = map(string)
}

variable "instance_type" {
  description = "See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html#AvailableInstanceTypes"
  default     = "t2.micro"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of SSH key pair to use as default (ec2-user) user key. Set in the launch template"
  default     = ""
  type        = string
}


/*
 * VPC configuration
 */

variable "aws_zones" {
  description = "The VPC availability zone list"
  default     = ["us-east-1c", "us-east-1d", "us-east-1e"]
  type        = list(string)
}


/*
 * ALB configuration
 */

variable "default_cert_domain_name" {
  description = "Default/primary certificate domain name. Used to reference an existing certificate for use in the ALB"
  type        = string
}

variable "disable_public_ipv4" {
  description = "Set to true to remove the public IPv4 addresses from the ALB. Requires enable_ipv6 = true"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Set to true to enable IPV6 in the ALB and VPC"
  type        = bool
  default     = false
}

variable "health_check" {
  description = "Elastic Load Balancer health check configuration"
  type        = map(string)
  default = {
    path    = "/"
    matcher = "200-399"
  }
}


/*
 * Database configuration
 */

variable "create_adminer" {
  description = "Set to true to create an Adminer database manager app instance"
  default     = false
  type        = bool
}

variable "database_name" {
  description = "The name assigned to the created database"
  default     = "db"
  type        = string
}

variable "database_user" {
  description = "The name of the database root user"
  default     = "root"
  type        = string
}

variable "database_allow_major_version_upgrade" {
  description = <<-EOT
    Indicates that major version upgrades are allowed. Changing this parameter does not result in an outage and the
    change is asynchronously applied as soon as possible.
  EOT
  default     = false
  type        = bool
}

variable "database_auto_minor_version_upgrade" {
  description = <<-EOT
    Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window.
    Database minor upgrades are changes to the patch version, e.g. 10.1.2 to 10.1.3.
  EOT
  default     = false
  type        = bool
}

variable "database_deletion_protection" {
  description = <<-EOT
    If the DB instance should have deletion protection enabled. The database can't be deleted when this value is
    set to true.
  EOT
  default     = false
  type        = bool
}

variable "database_engine_version" {
  description = <<-EOT
    The engine version to use. If auto_minor_version_upgrade is enabled, you can provide a prefix of the version such
    as 8.0 (for 8.0.36).
  EOT
  default     = "10.6.20"
  type        = string
}

variable "database_instance_class" {
  description = "The instance type of the RDS instance."
  default     = "db.t3.micro"
  type        = string
}

variable "database_multi_az" {
  description = "Specifies if the RDS instance is multi-availability-zone"
  default     = true
  type        = bool
}

variable "database_parameter_group_name" {
  description = "Name of the DB parameter group to associate."
  default     = null
  type        = string
}

variable "database_storage_encrypted" {
  description = <<-EOT
    Specifies whether the DB instance is encrypted. Note that if you are creating a cross-region read replica this
    field is ignored and you should instead declare kms_key_id with a valid ARN.
  EOT
  default     = false
  type        = bool
}

variable "rds_ca_cert_identifier" {
  description = "The identifier of the CA certificate for the DB instance."
  default     = null
  type        = string
}

variable "enable_adminer" {
  description = "Set to true to create a DNS record and start the Adminer app. Requires create_adminer = true."
  default     = false
  type        = bool
}
