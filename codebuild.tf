data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "codepipeline-sandbox" {
  bucket = "codepipeline-sandbox-artifacts-${data.aws_caller_identity.current.account_id}"
  acl    = "private"
}

resource "aws_iam_role" "codebuild-sandbox" {
  name = "codebuild-example-role"

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

resource "aws_iam_role_policy" "codebuild-sandbox" {
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
                "logs:PutLogEvents"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": [
              "${aws_s3_bucket.codepipeline-sandbox.arn}",
              "${aws_s3_bucket.codepipeline-sandbox.arn}/*"
            ],
            "Action": [
                "s3:*"
            ]
        }
    ]
}
POLICY
}

resource "aws_codebuild_project" "sandbox-master-build" {
  name          = "sandbox-master-build"
  description   = ""
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild-sandbox.arn}"

  artifacts {
    type = "S3"
    location = "${aws_s3_bucket.codepipeline-sandbox.bucket}"
    packaging = "ZIP"
  }
  
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/thedevsandbox/sandbox.git"
    auth {
      type = "OAUTH"
    }
    git_clone_depth = 1
  }
}

resource "aws_codebuild_webhook" "sandbox-master-build" {
  project_name = "${aws_codebuild_project.sandbox-master-build.name}"

  filter_group {
    filter {
      type = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type = "HEAD_REF"
      pattern = "refs/heads/master"
    }
  }
}

resource "aws_codebuild_project" "sandbox-pr-build" {
  name          = "sandbox-pr-build"
  description   = ""
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild-sandbox.arn}"

  artifacts {
    type = "NO_ARTIFACTS"
  }
  
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/thedevsandbox/sandbox.git"
    buildspec       = "testspec.yml"
    auth {
      type = "OAUTH"
    }
    git_clone_depth = 1
  }
}

resource "aws_codebuild_webhook" "cb-sandbox" {
  project_name = "${aws_codebuild_project.sandbox-pr-build.name}"

  filter_group {
    filter {
      type = "EVENT"
      pattern = "PULL_REQUEST_CREATED"
    }

    filter {
      type = "EVENT"
      pattern = "PULL_REQUEST_UPDATED"
    }
    
    filter {
      type = "EVENT"
      pattern = "PULL_REQUEST_REOPENED"
    }
  }
}