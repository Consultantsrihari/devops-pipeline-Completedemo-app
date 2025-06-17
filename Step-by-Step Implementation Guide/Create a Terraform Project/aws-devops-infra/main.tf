# main.tf

provider "aws" {
  region = "us-east-1" # Or your preferred region
}

# S3 Backend for Terraform State (Highly Recommended for production)
terraform {
  backend "s3" {
    bucket = "your-tf-state-bucket-unique-name" # Change this!
    key    = "devops-pipeline/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    dynamodb_table = "your-tf-state-lock-table" # Change this!
  }
}

# ----------------------------------------------------
# 1. VPC, Subnets, Internet Gateway, NAT Gateway
# ----------------------------------------------------
resource "aws_vpc" "devops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "devops-pipeline-vpc" }
}

resource "aws_internet_gateway" "devops_igw" {
  vpc_id = aws_vpc.devops_vpc.id
  tags = { Name = "devops-pipeline-igw" }
}

resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
  tags = { Name = "devops-pipeline-nat-eip" }
}

resource "aws_nat_gateway" "devops_nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet_az1.id # Public subnet for NAT Gateway
  vpc_id        = aws_vpc.devops_vpc.id
  tags = { Name = "devops-pipeline-nat-gateway" }
}

# Public Subnet (for Jenkins, ALB public interface)
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "devops-pipeline-public-az1" }
}

# Private Subnet (for ECS tasks, Prometheus, Grafana)
resource "aws_subnet" "private_subnet_az1" {
  vpc_id            = aws_vpc.devops_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"
  tags = { Name = "devops-pipeline-private-az1" }
}
resource "aws_subnet" "private_subnet_az2" {
  vpc_id            = aws_vpc.devops_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}b"
  tags = { Name = "devops-pipeline-private-az2" }
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.devops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devops_igw.id
  }
  tags = { Name = "devops-pipeline-public-rt" }
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.devops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.devops_nat_gateway.id
  }
  tags = { Name = "devops-pipeline-private-rt" }
}

resource "aws_route_table_association" "private_rt_association_az1" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_rt_association_az2" {
  subnet_id      = aws_subnet.private_subnet_az2.id
  route_table_id = aws_route_table.private_rt.id
}

# ----------------------------------------------------
# 2. Security Groups
# ----------------------------------------------------
resource "aws_security_group" "jenkins_sg" {
  vpc_id      = aws_vpc.devops_vpc.id
  name        = "jenkins-sg"
  description = "Allow SSH, HTTP (Jenkins)"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production!
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production!
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "jenkins-sg" }
}

resource "aws_security_group" "app_alb_sg" {
  vpc_id      = aws_vpc.devops_vpc.id
  name        = "app-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "app-alb-sg" }
}

resource "aws_security_group" "app_ecs_sg" {
  vpc_id      = aws_vpc.devops_vpc.id
  name        = "app-ecs-sg"
  description = "Allow inbound from ALB and outbound to anywhere"
  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    security_groups = [aws_security_group.app_alb_sg.id] # Only ALB can talk to ECS
  }
  ingress {
    from_port   = var.app_port # Allow internal communication for Prometheus
    to_port     = var.app_port
    protocol    = "tcp"
    security_groups = [aws_security_group.prometheus_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "app-ecs-sg" }
}

resource "aws_security_group" "prometheus_sg" {
  vpc_id      = aws_vpc.devops_vpc.id
  name        = "prometheus-sg"
  description = "Allow SSH, and scrape app metrics"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this!
  }
  ingress {
    from_port   = 9090 # Prometheus UI
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this!
  }
  ingress { # Allow Prometheus to scrape app
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    security_groups = [aws_security_group.app_ecs_sg.id] # Prometheus can talk to ECS
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "prometheus-sg" }
}

resource "aws_security_group" "grafana_sg" {
  vpc_id      = aws_vpc.devops_vpc.id
  name        = "grafana-sg"
  description = "Allow SSH, Grafana UI"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this!
  }
  ingress {
    from_port   = 3000 # Grafana UI
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this!
  }
  ingress { # Allow Grafana to query Prometheus
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    security_groups = [aws_security_group.prometheus_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "grafana-sg" }
}

# ----------------------------------------------------
# 3. IAM Roles and Policies
# ----------------------------------------------------
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = { Name = "jenkins-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "jenkins_policy_s3" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # For artifacts, customize later
}
resource "aws_iam_role_policy_attachment" "jenkins_policy_ecr" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}
resource "aws_iam_role_policy_attachment" "jenkins_policy_ecs" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess" # For deploying to ECS
}
resource "aws_iam_role_policy_attachment" "jenkins_policy_cloudwatch" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess" # For logs
}
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  tags = { Name = "ecs-task-execution-role" }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ----------------------------------------------------
# 4. EC2 Instances (Jenkins, Prometheus, Grafana)
# ----------------------------------------------------
resource "aws_key_pair" "devops_key" {
  key_name   = "devops-key" # Choose a unique name
  public_key = file("~/.ssh/id_rsa.pub") # Path to your public SSH key
}

resource "aws_instance" "jenkins_server" {
  ami                         = "ami-053b0d53cd7066567" # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type (us-east-1)
  instance_type               = "t2.medium" # t2.micro might be too small for Jenkins
  subnet_id                   = aws_subnet.public_subnet_az1.id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  key_name                    = aws_key_pair.devops_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
  associate_public_ip_address = true

  tags = { Name = "jenkins-server" }
}

resource "aws_instance" "prometheus_server" {
  ami                         = "ami-053b0d53cd7066567" # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type (us-east-1)
  instance_type               = "t2.small"
  subnet_id                   = aws_subnet.private_subnet_az1.id
  vpc_security_group_ids      = [aws_security_group.prometheus_sg.id]
  key_name                    = aws_key_pair.devops_key.key_name
  associate_public_ip_address = false # In private subnet
  tags = { Name = "prometheus-server" }
}

resource "aws_instance" "grafana_server" {
  ami                         = "ami-053b0d53cd7066567" # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type (us-east-1)
  instance_type               = "t2.small"
  subnet_id                   = aws_subnet.private_subnet_az2.id
  vpc_security_group_ids      = [aws_security_group.grafana_sg.id]
  key_name                    = aws_key_pair.devops_key.key_name
  associate_public_ip_address = false # In private subnet
  tags = { Name = "grafana-server" }
}

# ----------------------------------------------------
# 5. ECR (Elastic Container Registry)
# ----------------------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "${var.app_name}-ecr" }
}

# ----------------------------------------------------
# 6. ECS (Elastic Container Service)
# ----------------------------------------------------
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster"
  tags = { Name = "${var.app_name}-cluster" }
}

resource "aws_lb" "app_alb" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_alb_sg.id]
  subnets            = [aws_subnet.public_subnet_az1.id] # ALB in public subnet
  tags = { Name = "${var.app_name}-alb" }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.app_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devops_vpc.id
  target_type = "ip" # For Fargate

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
  tags = { Name = "${var.app_name}-tg" }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.app_tg.arn
    type             = "forward"
  }
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.app_name}-task"
  container_definitions    = jsonencode([
    {
      name      = var.app_name
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest" # Placeholder, Jenkins updates this
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.app_name}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  tags = { Name = "${var.app_name}-task" }
}

resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7
  tags = { Name = "${var.app_name}-log-group" }
}

resource "aws_ecs_service" "app_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 2 # Start with 2 instances for redundancy
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id]
    security_groups = [aws_security_group.app_ecs_sg.id]
    assign_public_ip = false # Fargate tasks in private subnets don't need public IPs
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = var.app_name
    container_port   = var.app_port
  }
  depends_on = [aws_lb_listener.app_listener] # Ensure listener is ready
  tags = { Name = "${var.app_name}-service" }
}
