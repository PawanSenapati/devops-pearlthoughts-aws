terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

variable "image_tag" {
  type = string
}

terraform {
  backend "s3" {
    bucket = "devops-interview-state"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# data "terraform_remote_state" "network" {
#   backend = "s3"
#   config = {
#     bucket = "devops-interview-state"
#     key    = "network/terraform.tfstate"
#     region = "us-east-1"
#   }
# }

# Create a new VPC for the ECS Fargate task
resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a new subnet in the VPC for the ECS Fargate task
resource "aws_subnet" "ecs_subnet_a" {
  vpc_id     = aws_vpc.ecs_vpc.id
  availability_zone = "us-east-1a"
}

# Create a new subnet in the VPC for the ECS Fargate task
resource "aws_subnet" "ecs_subnet_b" {
  vpc_id     = aws_vpc.ecs_vpc.id
  availability_zone = "us-east-1a"
}

# Define the ECS task
resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "my-ecs-task"
  container_definitions    = jsonencode([
    {
      name      = "my-container"
      image     = "${var.image_tag}"
      cpu       = 256
      memory    = 512
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  memory                   = "512"
  cpu                      = "256"
}

# Define the IAM role for the ECS task
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecs_task_execution.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Define the ECS service
resource "aws_ecs_service" "ecs_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn

  network_configuration {
    subnets = [aws_subnet.ecs_subnet_a.id,aws_subnet.ecs_subnet_b.id]
  }

  depends_on = [
    aws_ecs_task_definition.ecs_task,
  ]
}

# Define the ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

resource "aws_alb" "application_load_balancer" {
  name               = "load-balancer-dev" #load balancer name
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_subnet.ecs_subnet_a.id}",
    "${aws_subnet.ecs_subnet_b.id}"
  ]
  # security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
