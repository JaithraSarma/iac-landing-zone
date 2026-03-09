###############################################################################
# AWS CodePipeline Module
# Creates a native AWS CI/CD pipeline using CodePipeline + CodeBuild
# for Terraform plan (on PR) and apply (on merge).
#
# Components:
#   - S3 bucket for pipeline artifacts
#   - IAM roles for CodePipeline and CodeBuild
#   - CodeBuild projects for terraform plan & apply
#   - CodePipeline with Source -> Plan -> Approve -> Apply stages
###############################################################################

# --- Artifact Bucket ---
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${var.project_name}-pipeline-artifacts-${var.environment}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- IAM Role: CodeBuild ---
data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.project_name}-codebuild-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codebuild_policy" {
  # CloudWatch Logs
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  # S3 artifacts
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.pipeline_artifacts.arn,
      "${aws_s3_bucket.pipeline_artifacts.arn}/*"
    ]
  }

  # Terraform needs broad permissions to manage AWS resources
  statement {
    actions = [
      "ec2:*",
      "s3:*",
      "iam:*",
      "logs:*",
      "elasticloadbalancing:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.project_name}-codebuild-policy-${var.environment}"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

# --- IAM Role: CodePipeline ---
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.project_name}-codepipeline-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketVersioning"
    ]
    resources = [
      aws_s3_bucket.pipeline_artifacts.arn,
      "${aws_s3_bucket.pipeline_artifacts.arn}/*"
    ]
  }

  statement {
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = [var.codestar_connection_arn]
  }

  statement {
    actions = [
      "sns:Publish"
    ]
    resources = [aws_sns_topic.approval.arn]
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${var.project_name}-codepipeline-policy-${var.environment}"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

# --- SNS Topic for Manual Approval ---
resource "aws_sns_topic" "approval" {
  name = "${var.project_name}-approval-${var.environment}"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "approval_email" {
  count     = var.approval_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.approval.arn
  protocol  = "email"
  endpoint  = var.approval_email
}

# --- CodeBuild: Terraform Plan ---
resource "aws_codebuild_project" "terraform_plan" {
  name          = "${var.project_name}-tf-plan-${var.environment}"
  description   = "Terraform Plan for ${var.environment}"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "TF_ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        install:
          commands:
            - wget -q https://releases.hashicorp.com/terraform/$TF_VERSION/terraform_$${TF_VERSION}_linux_amd64.zip
            - unzip -o terraform_$${TF_VERSION}_linux_amd64.zip -d /usr/local/bin/
            - terraform version
        pre_build:
          commands:
            - cd environments/$TF_ENVIRONMENT
            - terraform init -input=false
            - terraform validate
        build:
          commands:
            - cd environments/$TF_ENVIRONMENT
            - terraform plan -out=tfplan -input=false
      artifacts:
        files:
          - environments/$TF_ENVIRONMENT/tfplan
          - "**/*"
    BUILDSPEC
  }

  tags = var.tags
}

# --- CodeBuild: Terraform Apply ---
resource "aws_codebuild_project" "terraform_apply" {
  name          = "${var.project_name}-tf-apply-${var.environment}"
  description   = "Terraform Apply for ${var.environment}"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 60

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "TF_ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        install:
          commands:
            - wget -q https://releases.hashicorp.com/terraform/$TF_VERSION/terraform_$${TF_VERSION}_linux_amd64.zip
            - unzip -o terraform_$${TF_VERSION}_linux_amd64.zip -d /usr/local/bin/
            - terraform version
        pre_build:
          commands:
            - cd environments/$TF_ENVIRONMENT
            - terraform init -input=false
        build:
          commands:
            - cd environments/$TF_ENVIRONMENT
            - |
              if [ -f tfplan ]; then
                terraform apply -auto-approve tfplan
              else
                terraform apply -auto-approve -input=false
              fi
        post_build:
          commands:
            - cd environments/$TF_ENVIRONMENT
            - terraform output -json
    BUILDSPEC
  }

  tags = var.tags
}

# --- CodePipeline ---
resource "aws_codepipeline" "this" {
  name     = "${var.project_name}-${var.environment}"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # Stage 1: Source from GitHub via CodeStar Connection
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.repository_id
        BranchName       = var.branch_name
      }
    }
  }

  # Stage 2: Terraform Plan
  stage {
    name = "Plan"

    action {
      name             = "TerraformPlan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["plan_output"]

      configuration = {
        ProjectName = aws_codebuild_project.terraform_plan.name
      }
    }
  }

  # Stage 3: Manual Approval
  stage {
    name = "Approve"

    action {
      name     = "ManualApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        NotificationArn = aws_sns_topic.approval.arn
        CustomData      = "Terraform plan for ${var.environment} is ready. Review and approve to apply."
      }
    }
  }

  # Stage 4: Terraform Apply
  stage {
    name = "Apply"

    action {
      name             = "TerraformApply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["plan_output"]
      output_artifacts = ["apply_output"]

      configuration = {
        ProjectName = aws_codebuild_project.terraform_apply.name
      }
    }
  }

  tags = var.tags
}
