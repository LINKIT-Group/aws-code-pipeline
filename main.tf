
resource "random_string" "s3" {
  length = 10
  special = false
  lower = true
  upper = false
}

resource "aws_s3_bucket" "source" {
  bucket        = "${var.name}-${var.environment}-${random_string.s3.result}"
  acl           = "private"
  force_destroy = true
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.name}-${var.environment}-codepipeline-role"

  assume_role_policy = "${file("${path.module}/policies/codepipeline_role.json")}"
}

/* policies */
data "template_file" "codepipeline_policy" {
  template = "${file("${path.module}/policies/codepipeline.json")}"

  vars = {
    aws_s3_bucket_arn = "${aws_s3_bucket.source.arn}"
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "${var.name}-${var.environment}-codepipeline_policy"
  role   = "${aws_iam_role.codepipeline_role.id}"
  policy = "${data.template_file.codepipeline_policy.rendered}"
}

/*
/* CodeBuild
*/
resource "aws_iam_role" "codebuild_role" {
  name               = "${var.name}-${var.environment}-codebuild-role"
  assume_role_policy = "${file("${path.module}/policies/codebuild_role.json")}"
}

data "template_file" "codebuild_policy" {
  template = "${file("${path.module}/policies/codebuild_policy.json")}"

  vars = {
    aws_s3_bucket_arn = "${aws_s3_bucket.source.arn}"
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name        = "${var.name}-${var.environment}-codebuild-policy"
  role        = "${aws_iam_role.codebuild_role.id}"
  policy      = "${data.template_file.codebuild_policy.rendered}"
}

data "template_file" "buildspec" {
  template = "${file("${path.module}/buildspec.yml")}"

  vars = {
    repository_url     = "${var.repository_url}"
    region             = "${var.region}"
    cluster_name       = "${var.ecs_cluster_name}"
    container_name     = "${var.container_name}"
  }
}

resource "aws_codebuild_project" "openjobs_build" {
  name          = "${var.name}-${var.environment}"
  service_role  = "${aws_iam_role.codebuild_role.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image           = "aws/codebuild/docker:1.12.1"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec.rendered}"
  }
}

/* CodePipeline */

resource "aws_codepipeline" "pipeline" {
  name     = "${var.name}-${var.environment}"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.source.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeCommit"
      version  = "1"
      output_artifacts = ["source"]

      configuration {
        RepositoryName = "${var.codecommit_repository_name}"
        BranchName = "${var.codecommit_branch_name}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["imagedefinitions"]

      configuration = {
        ProjectName = "${aws_codebuild_project.openjobs_build.name}"
      }
    }
  }

  stage {
    name = "Deploy-${var.environment}"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration = {
        ClusterName = "${var.ecs_cluster_name}"
        ServiceName = "${var.ecs_service_name}"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
