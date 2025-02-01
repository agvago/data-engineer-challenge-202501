#!/bin/bash

BUCKET_NAME="my-bucket"
LAMBDA_NAME="RegistrationProcess"
LAMBDA_ZIP="/tmp/lambda.zip"
ROLE_ARN="arn:aws:iam::000000000000:role/lambda-role"
FOLDER="sample_files"

function show_help {
    echo "Usage: ./run.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  --deploy       Deploy the Lambda function and set up the S3 trigger."
    echo "  --copy-files   Upload all files from 'sample_files/' to the S3 bucket."
    echo "  --help         Show this help message."
}

function deploy_lambda {
    echo "Deploying Lambda function..."

    # Ensure the handler file exists
    if [ ! -f "./lambda_function/lambda_function.py" ]; then
        echo "Error: Lambda handler file '/lambda_function/lambda_function.py' not found!"
        exit 1
    fi

    # Create the ZIP package
    rm -f $LAMBDA_ZIP
    cd lambda_function

    # Install dependencies in a separate folder
    pip install --no-deps --platform=manylinux2014_x86_64 --python-version=3.9 --only-binary=:all: --target=packages -r requirements.txt --index-url https://pypi.org/simple --upgrade

    # Remove unnecessary files to reduce size
    echo "Cleaning unnecessary files..."
    find packages -name "*.pyc" -delete
    find packages -name "__pycache__" -type d -exec rm -r {} +
    find packages -name "*.dist-info" -type d -exec rm -r {} +
    find packages -name "*.egg-info" -type d -exec rm -r {} +

    # Reduce size of shared libraries
    find packages -name "*.so" | xargs strip || true

    # Package everything into a single ZIP
    cd packages
    zip -r9 $LAMBDA_ZIP .
    cd ..
    zip -g $LAMBDA_ZIP lambda_function.py

    cd ..

    # Delete previous Lambda function if exists
    aws --endpoint-url=http://localhost:4566 lambda delete-function --function-name $LAMBDA_NAME --no-cli-pager 2>/dev/null || true

    # Create the Lambda function
    aws --endpoint-url=http://localhost:4566 lambda create-function \
        --function-name $LAMBDA_NAME \
        --runtime python3.9 \
        --role $ROLE_ARN \
        --memory-size 512 \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://$LAMBDA_ZIP \
        --no-cli-pager

    # Wait for the Lambda to be Active
    echo "Waiting for Lambda function '$LAMBDA_NAME' to be active..."
    while true; do
        STATE=$(aws --endpoint-url=http://localhost:4566 lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.State' --output text --no-cli-pager 2>/dev/null)
        if [[ "$STATE" == "Active" ]]; then
            echo "Lambda function '$LAMBDA_NAME' is active!"
            break
        fi
        echo "Still creating... waiting 5 seconds"
        sleep 5
    done

    # Add permission for S3 to invoke the Lambda
    echo "Adding permission for S3 to invoke Lambda '$LAMBDA_NAME'..."
    aws --endpoint-url=http://localhost:4566 lambda add-permission \
        --function-name $LAMBDA_NAME \
        --statement-id s3invoke \
        --action lambda:InvokeFunction \
        --principal s3.amazonaws.com \
        --source-arn arn:aws:s3:::$BUCKET_NAME \
        --no-cli-pager

    # Configure S3 event trigger for the 'stage/' folder
    echo "Configuring S3 event trigger for '$BUCKET_NAME' (only 'stage/' folder)..."
    aws --endpoint-url=http://localhost:4566 s3api put-bucket-notification-configuration \
        --bucket $BUCKET_NAME \
        --notification-configuration '{
            "LambdaFunctionConfigurations": [
                {
                    "LambdaFunctionArn": "arn:aws:lambda:us-east-1:000000000000:function:'$LAMBDA_NAME'",
                    "Events": ["s3:ObjectCreated:*"],
                    "Filter": {
                        "Key": {
                            "FilterRules": [
                                { "Name": "prefix", "Value": "stage/" }
                            ]
                        }
                    }
                }
            ]
        }' --no-cli-pager

    echo "Lambda function '$LAMBDA_NAME' deployed and configured to listen for events in 'stage/'!"
}

function upload_files {
    echo "Uploading files from '$FOLDER' to S3 bucket '$BUCKET_NAME'..."

    if [ ! -d "$FOLDER" ] || [ -z "$(ls -A $FOLDER)" ]; then
        echo "No files found in '$FOLDER'. Skipping upload."
        exit 1
    fi

    for file in $FOLDER/*; do
        if [ -f "$file" ]; then
            aws --endpoint-url=http://localhost:4566 s3 cp "$file" "s3://$BUCKET_NAME/stage/"
            echo "Uploaded: $file"
        fi
    done

    echo "All files uploaded successfully."
}

# Check the provided argument
case "$1" in
    --deploy)
        deploy_lambda
        ;;
    --copy-files)
        upload_files
        ;;
    --help|*)
        show_help
        ;;
esac
