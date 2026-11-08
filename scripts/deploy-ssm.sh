#!/usr/bin/env bash
set -euo pipefail
: "${INSTANCE_ID:?Configurar EC2_INSTANCE_ID en GitHub vars}"
: "${DOCKERHUB_USER:?Configurar DOCKERHUB_USERNAME en secrets}"
: "${S3_BUCKET:?Configurar S3_BUCKET en GitHub vars}"
: "${AWS_REGION:?Configurar AWS_REGION en GitHub vars}"
: "${IMAGE_TAG:?Configurar IMAGE_TAG}"
# Single string command for SSM avoids shell interpolation at the remote host.
COMMAND="cd /opt/cloudnative && printf '%s\n' 'DOCKERHUB_USER=${DOCKERHUB_USER}' 'IMAGE_TAG=${IMAGE_TAG}' 'S3_BUCKET=${S3_BUCKET}' 'AWS_REGION=${AWS_REGION}' > .env && docker compose -f docker-compose.aws.yml pull && docker compose -f docker-compose.aws.yml up -d --remove-orphans && curl --fail --retry 15 --retry-connrefused --retry-delay 2 http://127.0.0.1:8080/api/health"
# Inputs come from a restricted GitHub environment; check expected input formats.
[[ "$INSTANCE_ID" =~ ^i-[0-9a-f]{8,17}$ ]]
[[ "$DOCKERHUB_USER" =~ ^[a-zA-Z0-9_-]+$ ]]
[[ "$IMAGE_TAG" =~ ^[a-f0-9]{40}$ ]]
[[ "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]
[[ "$S3_BUCKET" =~ ^[a-z0-9.-]+$ ]]
PARAMS=$(jq -n --arg cmd "$COMMAND" '{commands:[$cmd],executionTimeout:["300"]}')
ID=$(aws ssm send-command --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript \
  --parameters "$PARAMS" --comment "Cloud Native GitHub Actions deploy" \
  --query 'Command.CommandId' --output text)
echo "SSM command $ID"
aws ssm wait command-executed --command-id "$ID" --instance-id "$INSTANCE_ID"
aws ssm get-command-invocation --command-id "$ID" --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Output:StandardOutputContent,Errors:StandardErrorContent}' --output json
