variable "name" {
  description = "name of the Application will be used to give names to services"
}

variable "environment" {
  description = "The environment will be used to give names to services"
}

variable "container_name" {
  description = "Name of container"
}

variable "repository_url" {
  description = "The url of the ECR repository"
}

variable "region" {
  description = "The region to use"
}

variable "ecs_cluster_name" {
  description = "The cluster that we will deploy"
}

variable "ecs_service_name" {
  description = "The ECS service that will be deployed"
}

variable "codecommit_repository_name" {
  description = "AWS Codecommit Repository Name"
}

variable "codecommit_branch_name" {
  description = "AWS Codecommit Branch Name"
}


