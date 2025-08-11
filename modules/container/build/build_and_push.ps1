# PowerShell script to build and push Docker image to ECR

# Set error action to stop on errors
$ErrorActionPreference = "Stop"

# Check if required environment variables are set
if (-not $env:AWS_REGION -or -not $env:AWS_ACCOUNT_ID -or -not $env:REPOSITORY_NAME -or -not $env:ECR_IMAGE) {
    Write-Error "Error: Required environment variables are not set."
    Write-Host "Required variables: AWS_REGION, AWS_ACCOUNT_ID, REPOSITORY_NAME, ECR_IMAGE"
    exit 1
}

# Login to ECR
Write-Host "Logging in to ECR..."
$loginPassword = aws --region $env:AWS_REGION ecr get-login-password
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get ECR login password"
    exit 1
}

$loginPassword | docker login --username AWS --password-stdin "$($env:AWS_ACCOUNT_ID).dkr.ecr.$($env:AWS_REGION).amazonaws.com"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to login to ECR"
    exit 1
}

# Build and push image for amd64 architecture (Fargate uses x86_64/amd64)
Write-Host "Building Docker image for amd64 architecture..."

# Parse build args if they exist
$buildArgsString = if ($env:BUILD_ARGS) { $env:BUILD_ARGS } else { "" }

# Use --platform to ensure we build for linux/amd64 even when building on different architectures
$buildCommand = "docker buildx build --platform linux/amd64 -t `"$($env:ECR_IMAGE)`" -f Dockerfile . $buildArgsString --load"
Write-Host "Running: $buildCommand"
Invoke-Expression $buildCommand
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Docker image"
    exit 1
}

# Push the image
Write-Host "Pushing image to ECR..."
docker push $env:ECR_IMAGE
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push Docker image"
    exit 1
}

Write-Host "Image successfully built and pushed to ECR"