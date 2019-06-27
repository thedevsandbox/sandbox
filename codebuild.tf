provider "aws" {
  region  = "ca-central-1"
}

data "aws_caller_identity" "current" {}

variable "environment" {
  type        = string
  description = "The deployment environment label."
  default = "stg"
}

locals {
  service = "sandbox"
  codePipelineBucketPrefix = "codepipeline-work-"
}

resource "aws_s3_bucket" "codepipeline-sandbox" {
  bucket = "${local.codePipelineBucketPrefix}-artifacts-${var.environment}-${data.aws_caller_identity.current.account_id}"
  acl    = "private"
}

resource "aws_iam_role" "codebuild-sandbox" {
  name = "CodeBuildRole-${local.service}-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role" "codepipeline-sandbox" {
  name = "CodePipelineRole-${local.service}-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild-sandbox" {
  name = "CodeBuildPolicy-${local.service}-${var.environment}"
  role = "${aws_iam_role.codebuild-sandbox.name}"
  
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": [
                "*"
            ],
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:FilterLogEvents",
                "logs:DescribeLogStreams",
                "logs:DeleteLogGroup",
                "s3:putObject",
                "s3:getObject",
                "codebuild:*",
                "cloudformation:List*",
                "cloudformation:Get*",
                "cloudformation:PreviewStackUpdate",
                "cloudformation:ValidateTemplate",
                "cloudformation:CreateStack",
                "cloudformation:CreateUploadBucket",
                "cloudformation:DeleteStack",
                "cloudformation:Describe*",
                "cloudformation:UpdateStack",
                "lambda:Get*",
                "lambda:List*",
                "lambda:CreateFunction",
                "lambda:AddPermission",
                "lambda:CreateAlias",
                "lambda:DeleteFunction",
                "lambda:InvokeFunction",
                "lambda:PublishVersion",
                "lambda:RemovePermission",
                "lambda:Update*",
                "apigateway:GET",
                "apigateway:POST",
                "apigateway:PUT",
                "apigateway:DELETE",
                "s3:CreateBucket",
                "s3:DeleteBucket",
                "s3:ListBucket",
                "s3:ListBucketVersions",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "iam:PassRole",
                "kinesis:*",
                "iam:GetRole",
                "iam:CreateRole",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:DeleteRole",
                "cloudwatch:GetMetricStatistics",
                "events:Put*",
                "events:Remove*",
                "events:Delete*",
                "dynamodb:*"      
            ]
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy" "codepipline-sandbox" {
  name = "CodePipelinePolicy-${local.service}-${var.environment}"
  role = "${aws_iam_role.codepipeline-sandbox.name}"
  
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Resource": [
              "*"
          ],
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "s3:putObject",
            "s3:getObject",
            "codebuild:*"
          ]
      }
  ]
}
POLICY
}

resource "aws_codebuild_project" "sandbox-test-build" {
  name          = "Test-Build"
  description   = "Demo of CodeBuild with CodeDeploy pipeline."
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild-sandbox.arn}"
  
  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec-${var.environment}.yml"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }
  artifacts {
    type = "CODEPIPELINE"
  }
}

resource "aws_codebuild_project" "sandbox-build-deploy" {
  name          = "Build-Deploy"
  description   = "Demo of CodeBuild with CodeDeploy pipeline."
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild-sandbox.arn}"
  
  source {
    type = "CODEPIPELINE"
    buildspec = <<BUILDSPEC
version: 0.2
  phases:
    build:
      commands:
        - bash deploy.sh
BUILDSPEC
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
      
    environment_variable {
      name  = "env"
      value = var.environment
      type  = "PLAINTEXT"
    }
  }
  artifacts {
    type = "CODEPIPELINE"
  }    
}

# CodePipeline with its stages:
resource "aws_codepipeline" "sandbox" {
  name = "DevOps-Pipeline-${local.service}"
  role_arn = "${aws_iam_role.codepipeline-sandbox.arn}"
  
  artifact_store {
    location = "${aws_s3_bucket.codepipeline-sandbox.bucket}"
    type     = "S3"
  }  
  # Stage 1:  Get the source from GitHub:
  stage {
    name = "Source"
    
    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        Owner = "thedevsandbox"
        Repo = "sandbox"
        Branch = "master"
        PollForSourceChanges = "true"
        OAuthToken = "3565729c4269342ca90d001aa3daa12d3a01d517"
      }
    }
  }
      
  # Stage 2:  Build using Serverless Framework
  stage {
    name = "Test-Build"
    
    action {
      name             = "Test-Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = "${aws_codebuild_project.sandbox-test-build.name}"
      }
    }
  }
  
  # Stage 3:  Build and Deploy using Serverless Framework
  stage {
    name = "Build-Deploy"
    
    action {
      name = "Build-Deploy"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      version = "1"
      input_artifacts = ["build_output"]
      output_artifacts = ["deploy_output"]
      configuration = {
        ProjectName = "${aws_codebuild_project.sandbox-build-deploy.name}"
      }
    }
  }
}

