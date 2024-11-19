provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}


resource "aws_subnet" "public_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "public_internet_gateway_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

resource "aws_route_table_association" "public_subnet_routes" {
  count          = 3
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_subnet_routes" {
  count          = 3
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "db_sg" {
  name        = "database_sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web_app_sg.id] # Allow traffic from the web app security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_db_subnet_group" "main_rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id
  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

resource "aws_db_parameter_group" "custom_rds_pg" {
  name   = "${var.project_name}-custom-rds-pg"
  family = var.db_engine_family

  parameter {
    name         = "max_connections"
    value        = "100"
    apply_method = "pending-reboot" # Change to 'pending-reboot' for static parameters
  }

  # Add other custom parameters here

  tags = {
    Name = "${var.project_name}-custom-rds-pg"
  }
}


resource "aws_db_instance" "main_rds" {
  allocated_storage      = 20
  engine                 = var.db_engine
  instance_class         = "db.t3.micro"
  db_subnet_group_name   = aws_db_subnet_group.main_rds_subnet_group.name
  identifier             = var.db_instance_identifier
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  parameter_group_name   = aws_db_parameter_group.custom_rds_pg.name
  tags = {
    Name = "${var.project_name}-rds"
  }
}




#**************************************************************************************************************************************

resource "aws_security_group" "load_balancer_sg" {
  name        = "load_balancer_sg"
  description = "Security group for Load Balancer"
  vpc_id      = aws_vpc.main_vpc.id

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
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"] # Allow all IPv4
    ipv6_cidr_blocks = ["::/0"]      # Allow all IPv6
  }

  tags = {
    Name = "${var.project_name}-load-balancer-sg"
  }
}

resource "aws_security_group" "web_app_sg" {
  name        = "web_app_sg"
  description = "Security group for web application"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = var.app_port # Adjust as per your app port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private_subnets[*].cidr_block
    # cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-app-sg"
  }
}

resource "aws_lb" "web_app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "web_app_tg" {
  name        = "${var.project_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"

  health_check {
    path                = "/healthz"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

resource "aws_lb_listener" "web_app_listener" {
  load_balancer_arn = aws_lb.web_app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app_tg.arn
  }
}

data "aws_ami" "custom_ami" {
  most_recent = true


  filter {
    name   = "name"
    values = ["network_fall_2024-webapp*"]
  }
  # $latest
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_launch_template" "web_app_launch_template" {
  name          = "${var.project_name}-launch-template"
  image_id      = data.aws_ami.custom_ami.id
  instance_type = var.instance_type # Define instance type in variable
  key_name      = var.key_pair_name

  network_interfaces {
    security_groups             = [aws_security_group.web_app_sg.id]
    associate_public_ip_address = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.combined_profile.name
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Write environment variables to a file in /opt/csye6225
              echo "DB_HOST=${aws_db_instance.main_rds.endpoint}" >> /opt/csye6225/App_Test/app.env
              echo "DB_USER=${var.db_username}" >> /opt/csye6225/App_Test/app.env
              echo "DB_PASSWORD=${var.db_password}" >> /opt/csye6225/App_Test/app.env
              echo "DB_NAME=${var.db_name}" >> /opt/csye6225/App_Test/app.env
              echo "DB_PORT=${var.db_port}" >> /opt/csye6225/App_Test/app.env
              echo "S3_BUCKET_NAME=${aws_s3_bucket.private_bucket.id}" >> /opt/csye6225/App_Test/app.env
              echo "SNS_TOPIC_ARN=${aws_sns_topic.user_verification.arn}" >> /opt/csye6225/App_Test/app.env
              echo "Region=${var.aws_region}" >> /opt/csye6225/App_Test/app.env 
              # Make the file readable by your application (adjust permissions as needed)
              sudo chown csye6225:csye6225 /opt/csye6225/App_Test/app.env
              chmod 644 /opt/csye6225/App_Test/app.env
              # Running the cloud watch
              sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/csye6225/App_Test/amazon-cloudwatch-agent.json -s
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-asg-instance"
    }
  }
}

resource "aws_autoscaling_group" "web_app_asg" {
  name                      = "custom_autoscaling_group"
  desired_capacity          = 3
  max_size                  = 5
  min_size                  = 3
  vpc_zone_identifier       = aws_subnet.public_subnets[*].id
  health_check_type         = "EC2"
  health_check_grace_period = 60
  target_group_arns         = [aws_lb_target_group.web_app_tg.arn]
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  launch_template {
    id      = aws_launch_template.web_app_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "csye6225_asg"
    propagate_at_launch = true
  }
}

# Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.web_app_asg.name

  metric_aggregation_type = "Average"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.web_app_asg.name

  metric_aggregation_type = "Average"
}

data "aws_route53_zone" "main" {
  name         = "${var.aws_profile}.${var.domain_name}"
  private_zone = false
}

resource "aws_route53_record" "web_app_dns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.aws_profile}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.web_app_alb.dns_name
    zone_id                = aws_lb.web_app_alb.zone_id
    evaluate_target_health = true
  }
}

# Scale Up CloudWatch Alarm - Trigger when CPU usage is above 5%
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_app_asg.name
  }
}

# Scale Down CloudWatch Alarm - Trigger when CPU usage is below 3%
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_low
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_app_asg.name
  }
}



#**************************************************************************************************************************************


#*****************************************This needs to be changed to launh template****************************************************

#*****************************************This needs to be changed to launh template****************************************************

resource "random_uuid" "bucket_uuid" {}

resource "aws_s3_bucket" "private_bucket" {
  bucket        = "${var.project_name}-s3-bucket-${random_uuid.bucket_uuid.result}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-s3-bucket"
  }
}


resource "aws_s3_bucket_public_access_block" "private_bucket" {
  bucket = aws_s3_bucket.private_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.private_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.private_bucket.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_iam_policy" "s3_access_policy" {
  name        = "${var.project_name}-cloudwatch-s3-policy"
  description = "Policy for CloudWatch and S3 access for EC2 instance"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource : [
          "arn:aws:logs:*:*:*"
        ]
      },
      {
        Effect : "Allow",
        Action : [
          "cloudwatch:PutMetricData"
        ],
        Resource : "*"
      },
      {
        Effect : "Allow",
        Action : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource : [
          "${aws_s3_bucket.private_bucket.arn}",
          "${aws_s3_bucket.private_bucket.arn}/*"
        ]
      }
    ]
  })

}



// Cloud Watch Agent Policyh 
resource "aws_iam_role" "combined_role" {
  name = "${var.project_name}-combined-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.combined_role.name # Update to use combined_role
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_iam_instance_profile" "combined_profile" {
  name = "${var.project_name}-combined-profile"
  role = aws_iam_role.combined_role.name
}
# Attach SNS Full Access Policy
resource "aws_iam_role_policy_attachment" "sns_policy_attachment" {
  role       = aws_iam_role.combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

#**********************************************************************************************************************************************

#Lambda Function and SNS

resource "aws_sns_topic" "user_verification" {
  name = "user-verification-topic"
}

data "archive_file" "lambda_zip" {
  type             = "zip"
  source_dir       = "../Serverless/venv/Lib/site-packages" # Path to the directory to zip
  output_file_mode = "0666"
  output_path      = "${path.module}/function.zip" # Output file in the current directory
}

resource "aws_lambda_function" "verification_email_lambda" {
  function_name = "send-verification-email"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda.lambda_handler"
  runtime       = "python3.9"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DOMAIN           = "${var.aws_profile}.${var.domain_name}"
      SENDGRID_API_KEY = var.send_grid_api_key
      base_url         = var.domain_name
      sns_topic_arn    = aws_sns_topic.user_verification.arn
      RDS_HOST         = aws_s3_bucket.private_bucket.id
      DB_NAME          = var.db_name
      DB_USER          = var.db_username
      DB_PASSWORD      = var.db_password
    }
  }

}

resource "aws_iam_role" "lambda_role" {
  name = "verification-email-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name        = "UserVerificationLambdaExecPolicy"
  description = "Policy to allow Lambda function to access SNS, RDS, and CloudWatch."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sns:Publish",
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["ses:SendEmail", "ses:SendRawEmail"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.verification_email_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_verification.arn
}

resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.user_verification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.verification_email_lambda.arn
}
