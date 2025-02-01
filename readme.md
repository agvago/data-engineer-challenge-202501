# DE Challenge

## Project Overview
This project provides a scalable and efficient solution for processing newly uploaded files in an S3 bucket using an AWS Lambda function. While the challenge initially suggested using a REST API, AWS already offers a built-in API for uploading files to S3. This approach eliminates the need for an additional REST API layer, streamlining the workflow. 

Once a file arrives in the bucket, the Lambda function is triggered, processes the file, and moves it to a designated folder based on predefined filename patterns. This design choice ensures efficient scaling and facilitates automated processing.

Additionally, I decided to implement this solution using AWS Lambda in LocalStack because I had never used it before and wanted to take this opportunity to explore its functionality.

## Tech Stack
- **Docker** for a containerized development environment
- **LocalStack** to simulate AWS services locally (S3, Lambda, IAM, etc.)
- **PostgreSQL** for structured data storage
- **Python (Boto3, SQLAlchemy)** for AWS interactions and database operations
- **s3fs** for handling S3 operations in LocalStack (could be replaced by `aws_s3` when using Redshift)

## Setup Instructions

### Prerequisites
Ensure you have the following installed:
- Docker
- Docker Compose

### Installation & Running
1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd <repository_folder>
   ```
2. Start the environment:
   ```bash
   docker-compose up -d
   ```
   This will start LocalStack and PostgreSQL in Docker containers.

The Lambda function performs the following tasks:
- Matches the filename against predefined patterns
- Determines the target schema and table
- Moves the file within S3 to the appropriate folder
- Loads the data into the corresponding PostgreSQL table

## Design Decisions
- **Fully Serverless Architecture:** The entire processing workflow is handled within an AWS Lambda function, ensuring scalability and reducing the need for additional infrastructure.
- **LocalStack for Development:** Used to simulate AWS services locally, eliminating costs and allowing for offline development.
- **Audit Logging:** Added fields such as `load_update_ts`, `filename`, and `row_number` to enhance traceability and data integrity.
- **Raw Data Layer:** Data is initially stored in a `hired_employees` table to reflect the source format as closely as possible. A future curated layer can aggregate and enhance this data.
- **Querying Strategy:** Queries are performed directly on the raw dataset, but an additional curated layer can be introduced for optimized queries.

## AWS Lambda Deployment & Testing
A helper script (`run.sh`) is provided to automate deployment and file uploads.

### Deploying the Lambda Function
To deploy the Lambda function and set up the S3 event trigger, run:
```bash
./run.sh --deploy
```
This script performs the following actions:
1. Packages the Lambda function and dependencies into a ZIP file.
2. Deploys the Lambda function to LocalStack.
3. Configures the S3 event trigger to invoke the Lambda function upon file uploads.

### Uploading Test Files to S3
To upload sample files from the `sample_files/` folder to the S3 bucket, run:
```bash
./run.sh --copy-files
```
This command simulates new files being added to S3, triggering the Lambda function for processing.

## AWS Logs & Troubleshooting
To inspect AWS Lambda logs in LocalStack, use the following commands:

- View filtered logs for the Lambda function:
  ```bash
  awslocal logs filter-log-events --log-group-name /aws/lambda/RegistrationProcess
  ```

- List log streams ordered by the latest event time:
  ```bash
  awslocal logs describe-log-streams --log-group-name /aws/lambda/RegistrationProcess --order-by LastEventTime --descending
  ```

- Fetch logs from a specific log stream:
  ```bash
  awslocal logs get-log-events --log-group-name /aws/lambda/RegistrationProcess --log-stream-name "2025/01/31/[$LATEST]6fd43f5484a7dd532e5323d360b1d495"
  ```

## Database Verification
- Validate S3 bucket contents:
  ```bash
  aws --endpoint-url=http://localhost:4566 s3 ls s3://my-bucket/
  ```
- Check PostgreSQL tables:
  ```bash
  docker exec -it postgres_db psql -U admin -d mydatabase
  ```

## Contributors
- **Author:** Agus
