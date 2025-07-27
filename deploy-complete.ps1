# ECS Deployment with Fixed IAM Role ARNs
Write-Host "Starting ECS deployment with fixed IAM role ARNs..." -ForegroundColor Green

$REGION = "ap-northeast-1"
$CLUSTER_NAME = "w2v-cluster"
$SERVICE_NAME = "w2v-api-service"
$TASK_FAMILY = "w2v-api-task"
$REPO_NAME = "w2v-api"

$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$EXECUTION_ROLE_ARN = "arn:aws:iam::$ACCOUNT_ID`:role/ecsTaskExecutionRole"
$TASK_ROLE_ARN = "arn:aws:iam::$ACCOUNT_ID`:role/ecsTaskRole"

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Account ID: $ACCOUNT_ID" -ForegroundColor White
Write-Host "  Execution Role: $EXECUTION_ROLE_ARN" -ForegroundColor White
Write-Host "  Task Role: $TASK_ROLE_ARN" -ForegroundColor White

# Create task definition with fixed ARNs
Write-Host "Creating task definition..." -ForegroundColor Yellow
$taskDefContent = @"
{
  "family": "$TASK_FAMILY",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "2048",
  "memory": "8192",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "taskRoleArn": "$TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "w2v-api",
      "image": "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME`:fixed-logger-v2",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "MODEL_TYPE",
          "value": "full"
        },
        {
          "name": "S3_BUCKET",
          "value": "my-w2v-models-2024"
        },
        {
          "name": "AWS_REGION",
          "value": "$REGION"
        },
        {
          "name": "PORT",
          "value": "8080"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/w2v-api",
          "awslogs-region": "$REGION",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 10,
        "retries": 3,
        "startPeriod": 300
      },
      "essential": true
    }
  ]
}
"@

$taskDefContent | Out-File -FilePath "final-task-definition.json" -Encoding utf8

# Register task definition
Write-Host "Registering task definition..." -ForegroundColor Yellow
try {
    $taskDefResult = (aws ecs register-task-definition --cli-input-json file://final-task-definition.json --region $REGION)
    Write-Host "✓ Task definition registered successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to register task definition" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get network configuration
Write-Host "Getting network configuration..." -ForegroundColor Yellow
$VPC_ID = (aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $REGION)
$SUBNET_IDS = (aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region $REGION)
$SUBNET_ARRAY = $SUBNET_IDS -split "\s+"

Write-Host "  VPC ID: $VPC_ID" -ForegroundColor White
Write-Host "  Subnets: $($SUBNET_ARRAY -join ', ')" -ForegroundColor White

# Get or create security group
Write-Host "Setting up security group..." -ForegroundColor Yellow
try {
    $SG_ID = (aws ec2 describe-security-groups --filters "Name=group-name,Values=w2v-api-sg" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text --region $REGION)
    if ($SG_ID -eq "None") {
        $SG_ID = (aws ec2 create-security-group --group-name w2v-api-sg --description "Security group for W2V API" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)
        Write-Host "✓ Security group created: $SG_ID" -ForegroundColor Green
    } else {
        Write-Host "✓ Using existing security group: $SG_ID" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Failed to setup security group" -ForegroundColor Red
}

# Add security group rules
try {
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region $REGION 2>$null
    Write-Host "✓ Security group rule added (or already exists)" -ForegroundColor Green
} catch {
    Write-Host "Security group rule already exists" -ForegroundColor Yellow
}

# Create ECS service
Write-Host "Creating ECS service..." -ForegroundColor Yellow
$serviceConfig = @"
{
  "serviceName": "$SERVICE_NAME",
  "taskDefinition": "$TASK_FAMILY",
  "desiredCount": 1,
  "launchType": "FARGATE",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": ["$($SUBNET_ARRAY[0])", "$($SUBNET_ARRAY[1])"],
      "securityGroups": ["$SG_ID"],
      "assignPublicIp": "ENABLED"
    }
  },
  "enableExecuteCommand": true
}
"@

$serviceConfig | Out-File -FilePath "service-config-final.json" -Encoding utf8

try {
    $serviceResult = (aws ecs create-service --cluster $CLUSTER_NAME --cli-input-json file://service-config-final.json --region $REGION)
    Write-Host "✓ ECS service created successfully" -ForegroundColor Green
} catch {
    Write-Host "Service might exist, trying to update..." -ForegroundColor Yellow
    try {
        aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $TASK_FAMILY --region $REGION | Out-Null
        Write-Host "✓ ECS service updated successfully" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to create/update service" -ForegroundColor Red
    }
}

# Wait for service to stabilize
Write-Host "Waiting for service to become stable..." -ForegroundColor Yellow
Write-Host "This may take 2-3 minutes..." -ForegroundColor Gray

try {
    aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION
    Write-Host "✓ Service is now stable" -ForegroundColor Green
} catch {
    Write-Host "⚠ Service deployment may still be in progress" -ForegroundColor Yellow
}

# Get service status
Write-Host "Getting service status..." -ForegroundColor Yellow
try {
    $serviceInfo = (aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION --query 'services[0]' --output json) | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "=== SERVICE STATUS ===" -ForegroundColor Cyan
    Write-Host "Service Name: $($serviceInfo.serviceName)" -ForegroundColor White
    Write-Host "Status: $($serviceInfo.status)" -ForegroundColor White
    Write-Host "Running Count: $($serviceInfo.runningCount)" -ForegroundColor White
    Write-Host "Desired Count: $($serviceInfo.desiredCount)" -ForegroundColor White
    Write-Host "Pending Count: $($serviceInfo.pendingCount)" -ForegroundColor White
    
    if ($serviceInfo.runningCount -gt 0) {
        Write-Host ""
        Write-Host "🎉 DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
        Write-Host "Your W2V API is now running on AWS ECS Fargate" -ForegroundColor Green
        
        # Get task details for public IP
        $tasks = (aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $REGION --query 'taskArns' --output json) | ConvertFrom-Json
        if ($tasks.Count -gt 0) {
            $taskDetails = (aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $tasks[0] --region $REGION --query 'tasks[0]' --output json) | ConvertFrom-Json
            
            # Get ENI details
            $eniId = ($taskDetails.attachments[0].details | Where-Object { $_.name -eq "networkInterfaceId" }).value
            if ($eniId) {
                $publicIp = (aws ec2 describe-network-interfaces --network-interface-ids $eniId --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region $REGION)
                if ($publicIp -and $publicIp -ne "None") {
                    Write-Host ""
                    Write-Host "🌐 API Endpoint: http://$publicIp`:8080" -ForegroundColor Cyan
                    Write-Host "Health Check: http://$publicIp`:8080/health" -ForegroundColor Cyan
                }
            }
        }
    } else {
        Write-Host ""
        Write-Host "⚠ Service deployed but no tasks running yet" -ForegroundColor Yellow
        Write-Host "Check logs for startup issues" -ForegroundColor White
    }
    
} catch {
    Write-Host "Could not get service status" -ForegroundColor Yellow
}

# Clean up temporary files
Remove-Item -Path "final-task-definition.json" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "service-config-final.json" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== MONITORING COMMANDS ===" -ForegroundColor Yellow
Write-Host "Service status:" -ForegroundColor White
Write-Host "  aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION" -ForegroundColor Gray
Write-Host ""
Write-Host "View logs:" -ForegroundColor White
Write-Host "  aws logs tail /ecs/w2v-api --follow --region $REGION" -ForegroundColor Gray
Write-Host ""
Write-Host "List running tasks:" -ForegroundColor White
Write-Host "  aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $REGION" -ForegroundColor Gray
