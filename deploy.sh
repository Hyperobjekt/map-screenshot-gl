#!/usr/bin/env bash

set -o pipefail
set -e
set -x

AWS_PROFILE="${AWS_PROFILE:-client-admin}"
ECR_REGISTRY="318011162599.dkr.ecr.us-east-1.amazonaws.com"
ECR_IMAGE="${ECR_REGISTRY}/map-screenshot-gl"
IMAGE_TAG="$(git rev-parse --short HEAD)"

aws --profile "$AWS_PROFILE" --region us-east-1 ecr get-login-password \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker build -t "${ECR_IMAGE}:${IMAGE_TAG}" .
docker push "${ECR_IMAGE}:${IMAGE_TAG}"

RENDERED_TEMPLATE="$(mktemp)"
trap 'rm -f "$RENDERED_TEMPLATE"' EXIT
sed "s/IMAGE_TAG/${IMAGE_TAG}/g" ./ecs.yml > "$RENDERED_TEMPLATE"

TEMPLATE_VERSION_FILENAME="map-screenshot-gl-ecs-date:$(date -r "$RENDERED_TEMPLATE" +'%Y-%m-%dT%H:%M:%SZ')-git:${IMAGE_TAG}-file:$(sha256sum "$RENDERED_TEMPLATE" | head -c 20).yml"
export TEMPLATE_VERSION_FILENAME

aws --profile "$AWS_PROFILE" --region us-east-1 \
  s3 cp "$RENDERED_TEMPLATE" "s3://map-screenshot-gl-cloudformation/${TEMPLATE_VERSION_FILENAME}"

aws --profile "$AWS_PROFILE" --region us-east-1 \
  cloudformation update-stack \
    --stack-name map-screenshot-cluster \
    --template-url "https://map-screenshot-gl-cloudformation.s3.amazonaws.com/${TEMPLATE_VERSION_FILENAME}" \
    --capabilities CAPABILITY_IAM \
    --parameters \
      ParameterKey=KeyName,ParameterValue=ami-testing \
      ParameterKey=LoadBalancerCertificateArn,ParameterValue=arn:aws:acm:us-east-1:318011162599:certificate/e73f1755-88e9-4a29-8909-e39f02cd04bf \
      ParameterKey=SubnetId,ParameterValue="subnet-0abbf006\,subnet-3d520d11\,subnet-4f51862b\,subnet-7a0d1032\,subnet-c404549e\,subnet-dbc034e4" \
      ParameterKey=VpcId,ParameterValue=vpc-7e251507

aws --profile "$AWS_PROFILE" --region us-east-1 \
  cloudformation wait stack-update-complete \
    --stack-name map-screenshot-cluster

aws --profile hyperobjekt --region us-east-1 \
  ecs describe-services  \
    --cluster map-screenshot-cluster-ECSCluster-6CEKKPS6CZ9O \
    --services map-screenshot-cluster-service-8PXOICK7M3S6
