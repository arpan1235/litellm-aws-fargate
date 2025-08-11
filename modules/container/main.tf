# AWS Account - Get current account ID for ECR repository
data "aws_caller_identity" "current" {}

# Container Registry - ECR repository with vulnerability scanning
resource "aws_ecr_repository" "repository" {
  name = var.repository_name

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# Build - Generate deterministic image tag from content hashes
locals {
  content_hash = substr(sha256(join("", [
    filesha256("${path.module}/image/Dockerfile"),
    filesha256("${path.module}/image/litellm_config_load_balance.yaml"),
    filesha256("${path.module}/image/entrypoint.sh")
  ])), 0, 8)

  ecr_image_tag = local.content_hash
  ecr_image_uri = "${aws_ecr_repository.repository.repository_url}:${local.ecr_image_tag}"
}


# Deployment - Build and push Docker image using local-exec script
resource "null_resource" "docker_build_and_push" {
  provisioner "local-exec" {
    working_dir = "${path.module}/image"
    interpreter = ["C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "-Command"]
    command = <<-EOT
      aws --region ${var.aws_region} ecr get-login-password | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      docker buildx build --platform linux/amd64 -t "${local.ecr_image_uri}" -f Dockerfile . ${join(" ", [for key, value in var.build_args : "--build-arg ${key}=${value}"])} --load
      docker push "${local.ecr_image_uri}"
    EOT
  }

  triggers = {
    content_hash = local.content_hash
  }

  depends_on = [aws_ecr_repository.repository]
}
