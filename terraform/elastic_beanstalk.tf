resource "aws_elastic_beanstalk_environment" "fittrack" {
  name        = "${var.app_name}-${var.environment}-env"
  application = aws_elastic_beanstalk_application.fittrack.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.6.7 running Node.js 20"

  # Instance profile
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.elastic_beanstalk_ec2.name
  }

  # Security Groups (launch configuration)
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = join(",", [aws_security_group.elastic_beanstalk.id])
  }

  # Environment type
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  # Instance type
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  # Min/Max instances
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "3"
  }

  # VPC configuration
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "Subnets"
    value     = join(",", aws_subnet.public[*].id)
  }

  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = aws_security_group.elastic_beanstalk.id
  }

  # Environment variables
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
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DATABASE_URL"
    value     = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.fittrack.endpoint}/${aws_db_instance.fittrack.db_name}"
  }

  tags = var.tags

  depends_on = [
    aws_elastic_beanstalk_application.fittrack,
    aws_db_instance.fittrack,
    aws_security_group.elastic_beanstalk
  ]
}
