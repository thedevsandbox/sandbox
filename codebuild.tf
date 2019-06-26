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
                "arn:aws:s3:::codepipeline-ca-central-1-*"
            ],
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
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