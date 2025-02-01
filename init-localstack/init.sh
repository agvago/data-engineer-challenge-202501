#!/bin/bash

echo "Waiting for LocalStack to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"s3": "running"'; do
    sleep 5
done

echo "LocalStack is ready. Creating resources..."

# Create an S3 bucket named 'my-bucket'
aws --endpoint-url=http://localhost:4566 s3 mb s3://my-bucket || echo "Bucket already exists"

echo "S3 bucket 'my-bucket' created."

# Create log group and log stream for lambda
aws --endpoint-url=http://localhost:4566 logs create-log-group --log-group-name /aws/lambda/RegistrationProcess || echo "Log group already exists"
echo "Log group '/aws/lambda/RegistrationProcess' created."

aws --endpoint-url=http://localhost:4566 logs create-log-stream --log-group-name /aws/lambda/RegistrationProcess --log-stream-name "predefined-log-stream" || echo "Log stream already exists"
echo "Log stream 'predefined-log-stream' created."

echo "All resources initialized successfully."
