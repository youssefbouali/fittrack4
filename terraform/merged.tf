# CloudFront distribution for frontend
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3Frontend"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.frontend.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Frontend"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior for /api/* - pass through to backend
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Frontend"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      cookies {
        forward = "all"
      }
    }
    

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # Cache behavior for static assets
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3Frontend"
    viewer_protocol_policy = "https-only"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Custom error response
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [aws_s3_bucket.frontend, aws_cloudfront_origin_access_identity.frontend]

  tags = var.tags
}

resource "aws_cloudfront_origin_access_identity" "frontend" {
  comment = "OAI for FitTrack frontend"
}

# CloudFront distribution for activity photos
resource "aws_cloudfront_distribution" "activity_photos" {
  origin {
    domain_name = aws_s3_bucket.activity_photos.bucket_regional_domain_name
    origin_id   = "S3Photos"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.photos.cloudfront_access_identity_path
    }
  }

  enabled         = true
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Photos"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [aws_s3_bucket.activity_photos, aws_cloudfront_origin_access_identity.photos]

  tags = var.tags
}

resource "aws_cloudfront_origin_access_identity" "photos" {
  comment = "OAI for FitTrack activity photos"
}
resource "aws_cognito_user_pool" "fittrack" {
  name = "${var.app_name}-${var.environment}-pool"

  password_policy {
    minimum_length    = var.cognito_password_min_length
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  username_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  schema {
    name              = "email"
    attribute_data_type = "String"
    mutable           = true
    required          = true
  }

  schema {
    name              = "name"
    attribute_data_type = "String"
    mutable           = true
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "fittrack_web" {
  name                = "${var.app_name}-${var.environment}-web-client"
  user_pool_id        = aws_cognito_user_pool.fittrack.id
  generate_secret     = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  allowed_oauth_flows = ["code", "implicit"]
  allowed_oauth_scopes = [
    "phone",
    "email",
    "openid",
    "profile",
  ]
  allowed_oauth_flows_user_pool_client = true

  callback_urls = concat(
    ["http://localhost:3000/auth/callback"],
    var.frontend_domain != "" ? ["https://${var.frontend_domain}/auth/callback"] : []
  )

  logout_urls = concat(
    ["http://localhost:3000"],
    var.frontend_domain != "" ? ["https://${var.frontend_domain}"] : []
  )

  read_attributes  = ["email", "name", "phone_number"]
  write_attributes = ["email", "name", "phone_number"]

  depends_on = [aws_cognito_user_pool.fittrack]
}

resource "aws_cognito_identity_pool" "fittrack" {
  identity_pool_name             = "${var.app_name}_${var.environment}_identity_pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id              = aws_cognito_user_pool_client.fittrack_web.id
    provider_name          = aws_cognito_user_pool.fittrack.endpoint
    #server_side_token_validation = false
  }

  depends_on = [aws_cognito_user_pool.fittrack, aws_cognito_user_pool_client.fittrack_web]
}

resource "aws_cognito_identity_pool_roles_attachment" "fittrack" {
  identity_pool_id = aws_cognito_identity_pool.fittrack.id

  roles = {
    authenticated   = aws_iam_role.cognito_authenticated.arn
    unauthenticated = aws_iam_role.cognito_unauthenticated.arn
  }

  depends_on = [
    aws_cognito_identity_pool.fittrack,
    aws_iam_role.cognito_authenticated,
    aws_iam_role.cognito_unauthenticated
  ]
}

resource "aws_iam_role" "cognito_authenticated" {
  name = "${var.app_name}-${var.environment}-cognito-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.fittrack.id
          }
          ForAllValues = {
            "cognito-identity.amazonaws.com:auth_time" = "authenticated"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cognito_authenticated_s3" {
  name   = "${var.app_name}-${var.environment}-cognito-s3-policy"
  role   = aws_iam_role.cognito_authenticated.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.activity_photos.arn}/activities/$${aws:username}/*"
      }
    ]
  })
}

resource "aws_iam_role" "cognito_unauthenticated" {
  name = "${var.app_name}-${var.environment}-cognito-unauth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.fittrack.id
          }
        }
      }
    ]
  })
}
resource "aws_security_group" "elastic_beanstalk" {
  name        = "${var.app_name}-${var.environment}-eb-sg"
  description = "Security group for Elastic Beanstalk"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_iam_role" "elastic_beanstalk_ec2" {
  name = "${var.app_name}-${var.environment}-eb-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "elastic_beanstalk_web_tier" {
  role       = aws_iam_role.elastic_beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "elastic_beanstalk_worker_tier" {
  role       = aws_iam_role.elastic_beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "elastic_beanstalk_ssm" {
  role       = aws_iam_role.elastic_beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "elastic_beanstalk_secrets_manager" {
  name = "${var.app_name}-${var.environment}-eb-secrets-policy"
  role = aws_iam_role.elastic_beanstalk_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
          aws_secretsmanager_secret.cognito_credentials.arn
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "elastic_beanstalk_ec2" {
  name = "${var.app_name}-${var.environment}-eb-ec2-profile"
  role = aws_iam_role.elastic_beanstalk_ec2.name
}

resource "aws_elastic_beanstalk_application" "fittrack" {
  name            = "${var.app_name}-${var.environment}"
  description     = "FitTrack application"
  #service_role    = aws_iam_role.elastic_beanstalk_service.arn

  tags = var.tags
}

resource "aws_iam_role" "elastic_beanstalk_service" {
  name = "${var.app_name}-${var.environment}-eb-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "elastic_beanstalk_service" {
  role       = aws_iam_role.elastic_beanstalk_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_elastic_beanstalk_environment" "fittrack" {
  name            = "${var.app_name}-${var.environment}-env"
  application     = aws_elastic_beanstalk_application.fittrack.name
  solution_stack_name = "64bit Amazon Linux 2 v5.8.1 running Node.js 18"
  environment_type = "LoadBalanced"
  instance_type   = "t3.micro"
  min_instances   = 1
  max_instances   = 3

  vpc_id = aws_vpc.main.id
  subnets = join(",", aws_subnet.public[*].id)
  security_groups = aws_security_group.elastic_beanstalk.id

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = var.environment
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PORT"
    value     = "5000"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "AWS_REGION"
    value     = var.aws_region
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "COGNITO_USER_POOL_ID"
    value     = aws_cognito_user_pool.fittrack.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "COGNITO_CLIENT_ID"
    value     = aws_cognito_user_pool_client.fittrack_web.id
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.elastic_beanstalk_ec2.name
  }

  environment_variables = {
    DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.fittrack.endpoint}/${aws_db_instance.fittrack.db_name}"
  }

  tags = var.tags

  depends_on = [
    aws_elastic_beanstalk_application.fittrack,
    aws_db_instance.fittrack,
    aws_security_group.elastic_beanstalk
  ]
}

#output "elastic_beanstalk_endpoint" {
#  value       = aws_elastic_beanstalk_environment.fittrack.endpoint_url
#  description = "Elastic Beanstalk environment endpoint"
#}
locals {
  app_name_lower = lower(var.app_name)
  common_tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
      CreatedAt = timestamp()
    }
  )
}

# Null resource for outputs
resource "null_resource" "deployment_summary" {
  provisioner "local-exec" {
    command = "echo 'FitTrack infrastructure deployment complete!'"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.environment}-vpc"
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.environment}-igw"
    }
  )
}

# Public subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.environment}-public-subnet-${count.index + 1}"
    }
  )
}

# Private subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.environment}-private-subnet-${count.index + 1}"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.environment}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways for private subnets
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.environment}-nat-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.environment}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route tables for private subnets
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-${var.environment}-private-rt-${count.index + 1}"
    }
  )
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}
output "region" {
  value       = var.aws_region
  description = "AWS region"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "frontend_bucket_name" {
  value       = aws_s3_bucket.frontend.id
  description = "S3 bucket for frontend"
}

output "activity_photos_bucket_name" {
  value       = aws_s3_bucket.activity_photos.id
  description = "S3 bucket for activity photos"
}

output "frontend_cloudfront_domain" {
  value       = aws_cloudfront_distribution.frontend.domain_name
  description = "CloudFront domain for frontend"
}

output "photos_cloudfront_domain" {
  value       = aws_cloudfront_distribution.activity_photos.domain_name
  description = "CloudFront domain for activity photos"
}

output "frontend_cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.frontend.id
  description = "CloudFront distribution ID for frontend"
}

output "photos_cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.activity_photos.id
  description = "CloudFront distribution ID for photos"
}

output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.fittrack.id
  description = "Cognito User Pool ID"
}

output "cognito_user_pool_client_id" {
  value       = aws_cognito_user_pool_client.fittrack_web.id
  description = "Cognito User Pool Client ID"
}

output "cognito_identity_pool_id" {
  value       = aws_cognito_identity_pool.fittrack.id
  description = "Cognito Identity Pool ID"
}

output "rds_endpoint" {
  value       = aws_db_instance.fittrack.endpoint
  description = "RDS database endpoint"
  sensitive   = true
}

output "elastic_beanstalk_endpoint" {
  value       = aws_elastic_beanstalk_environment.fittrack.endpoint_url
  description = "Elastic Beanstalk endpoint URL"
}

output "secrets_manager_arn_db" {
  value       = aws_secretsmanager_secret.db_credentials.arn
  description = "ARN for DB credentials in Secrets Manager"
}

output "secrets_manager_arn_cognito" {
  value       = aws_secretsmanager_secret.cognito_credentials.arn
  description = "ARN for Cognito credentials in Secrets Manager"
}

output "secrets_manager_arn_aws" {
  value       = aws_secretsmanager_secret.aws_credentials.arn
  description = "ARN for AWS credentials in Secrets Manager"
}
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 4.60"
    }
  }

  backend "s3" {
    bucket         = "fittrack-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

provider "random" {}
resource "aws_db_subnet_group" "fittrack" {
  name       = "${var.app_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = var.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.app_name}-${var.environment}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.elastic_beanstalk.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_db_instance" "fittrack" {
  identifier            = "${var.app_name}-${var.environment}-db"
  engine                = "postgres"
  engine_version        = "14.15"
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  storage_encrypted     = true
  db_subnet_group_name  = aws_db_subnet_group.fittrack.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  db_name  = replace(var.db_name, "-", "_")
  username = var.db_username
  password = var.db_password

  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  multi_az                = false
  publicly_accessible     = false

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.app_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmmss", timestamp())}"

  tags = var.tags

  depends_on = [aws_security_group.rds, aws_db_subnet_group.fittrack]
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.app_name}/${var.environment}/db"
  description             = "RDS database credentials for FitTrack"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.fittrack.username
    password = var.db_password
    host     = aws_db_instance.fittrack.endpoint
    port     = 5432
    dbname   = aws_db_instance.fittrack.db_name
    engine   = "postgresql"
  })
}

output "db_endpoint" {
  value       = aws_db_instance.fittrack.endpoint
  description = "RDS database endpoint"
}

output "db_name" {
  value       = aws_db_instance.fittrack.db_name
  description = "RDS database name"
}

output "db_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.db_credentials.arn
  description = "ARN of the RDS credentials secret"
}
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket for frontend static content
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.app_name}-frontend-${var.environment}-${random_string.bucket_suffix.result}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_cloudfront_distribution.frontend]
}

# S3 bucket for activity photos
resource "aws_s3_bucket" "activity_photos" {
  bucket = "${var.app_name}-photos-${var.environment}-${random_string.bucket_suffix.result}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "activity_photos" {
  bucket = aws_s3_bucket.activity_photos.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "activity_photos" {
  bucket = aws_s3_bucket.activity_photos.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_origins = concat(
      ["http://localhost:3000", "http://localhost:3001"],
      var.frontend_domain != "" ? ["https://${var.frontend_domain}"] : []
    )
    expose_headers = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "activity_photos" {
  bucket = aws_s3_bucket.activity_photos.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "activity_photos" {
  bucket = aws_s3_bucket.activity_photos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.activity_photos.arn}/*"
      },
      {
        Sid    = "AllowCognitoUserUpload"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.cognito_authenticated.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.activity_photos.arn}/activities/*"
      }
    ]
  })

  depends_on = [
    aws_iam_role.cognito_authenticated,
    aws_cloudfront_distribution.activity_photos
  ]
}
resource "aws_secretsmanager_secret" "cognito_credentials" {
  name                    = "${var.app_name}/${var.environment}/cognito"
  description             = "Cognito credentials for FitTrack"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "cognito_credentials" {
  secret_id = aws_secretsmanager_secret.cognito_credentials.id
  secret_string = jsonencode({
    user_pool_id = aws_cognito_user_pool.fittrack.id
    client_id    = aws_cognito_user_pool_client.fittrack_web.id
    region       = var.aws_region
  })
}

resource "aws_secretsmanager_secret" "aws_credentials" {
  name                    = "${var.app_name}/${var.environment}/aws"
  description             = "AWS credentials for FitTrack"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "aws_credentials" {
  secret_id = aws_secretsmanager_secret.aws_credentials.id
  secret_string = jsonencode({
    region           = var.aws_region
    s3_bucket        = aws_s3_bucket.activity_photos.id
    identity_pool_id = aws_cognito_identity_pool.fittrack.id
  })
}

output "cognito_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.cognito_credentials.arn
  description = "ARN of the Cognito credentials secret"
}

output "aws_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.aws_credentials.arn
  description = "ARN of the AWS credentials secret"
}
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "fittrack"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "fittrack_db"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
  default     = "postgres"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Database allocated storage in GB"
  type        = number
  default     = 20
}

variable "cognito_password_min_length" {
  description = "Cognito password minimum length"
  type        = number
  default     = 8
}

variable "frontend_domain" {
  description = "Frontend domain name"
  type        = string
  default     = ""
}

variable "api_domain" {
  description = "API domain name"
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Enable HTTPS/SSL"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "FitTrack"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
