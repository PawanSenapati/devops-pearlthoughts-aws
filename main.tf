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
  access_key = ${{secrets.AWS_ACCESS_KEY}}
  secret_key = ${{secrets.AWS_SECRET_KEY}}
}

variable "image_tag" {
  type = string
}

terraform {
  backend "s3" {
    bucket = "devops-interview-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-state-prod"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "google_cloud_run_service" "app_service" {
  name     = "devops-interview"
  location = "us-central1"
  
  template {
    spec {
      containers {
        image = "gcr.io/gcp-devops-376307/devops-inter:${var.image_tag}"
      }
    }
  }
}

# Create a new VPC for the ECS Fargate task
resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a new subnet in the VPC for the ECS Fargate task
resource "aws_subnet" "ecs_subnet" {
  vpc_id     = aws_vpc.ecs_vpc.id
  cidr_block = "10.0.1.0/24"
}

# Define the ECS task
resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "my-ecs-task"
  container_definitions    = jsonencode([
    {
      name      = "my-container"
      image     = "nginx:latest"
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

# Allow the task to read the ECR repository
  # You can customize the permissions as needed
  inline_policy {
    name = "ecs-task-ecr-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetRepositoryPolicy",
            "ecr:DescribeRepositories",
            "ecr:ListImages",
            "ecr:BatchGetImage"
          ],
          Resource = ["*"]
        }
      ]
    })
  }
}

# Define the ECS service
resource "aws_ecs_service" "ecs_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn

  network_configuration {
    subnets = [aws_subnet.ecs_subnet.id]
  }

  depends_on = [
    aws_ecs_task_definition.ecs_task,
  ]
}

# Define the ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}
