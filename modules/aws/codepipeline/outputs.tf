###############################################################################
# AWS CodePipeline Module - Outputs
###############################################################################

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.this.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.this.arn
}

output "plan_project_name" {
  description = "Name of the Terraform Plan CodeBuild project"
  value       = aws_codebuild_project.terraform_plan.name
}

output "apply_project_name" {
  description = "Name of the Terraform Apply CodeBuild project"
  value       = aws_codebuild_project.terraform_apply.name
}

output "artifact_bucket" {
  description = "S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "approval_topic_arn" {
  description = "SNS topic ARN for manual approvals"
  value       = aws_sns_topic.approval.arn
}
