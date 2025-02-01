import json
import boto3
import pandas as pd
import re
from io import StringIO
from datetime import datetime
import logging
from sqlalchemy import create_engine

# Temporary configuration for table mappings and data types.
# This should be replaced by a configuration file or database table.
LAMBDA_CONFIG = {
    r'^departments_.*\.csv$': {
        'table': 'departments',
        'has_header': False,
        'columns': {
            'id': 'int64',
            'department_name': 'string',
            'load_file_name': 'string',
            'load_timestamp': 'datetime64[ns]',
            'load_row_number': 'int64'
        }
    },
    r'^hired_employees_.*\.csv$': {
        'table': 'hired_employees',
        'has_header': False,
        'columns': {
                'id': 'int64',
                'employee_name': 'string',
                'hire_datetime': 'datetime64[ns]',
                'department_id': 'int64',
                'job_id': 'int64',
                'load_file_name': 'string',
                'load_timestamp': 'datetime64[ns]',
                'load_row_number': 'int64'
            }
    },
    r'^jobs.*\.csv$': {
        'table': 'jobs',
        'has_header': False,
        'columns': {
                'id': 'int64',
                'job_name': 'string',
                'load_file_name': 'string',
                'load_timestamp': 'datetime64[ns]',
                'load_row_number': 'int64'
            }
    }
}

def get_target_table(filename):
    """
    Determines the target table and column configuration based on the filename.
    """
    for pattern, config in LAMBDA_CONFIG.items():
        if re.match(pattern, filename):
            return config
    return None

def lambda_handler(event, context):
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    try:
        logger.info(f"Received event: {json.dumps(event)}")

        # Validate if event contains records
        if 'Records' not in event:
            logger.error("Error: No 'Records' found in event.")
            return {'statusCode': 400, 'body': json.dumps("Invalid event: Missing 'Records'")}

        # Initialize S3 and PostgreSQL connections
        s3 = boto3.client('s3', endpoint_url='http://localstack:4566')

        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']

            # Ensure the file is in the 'stage/' folder
            if not object_key.startswith("stage/"):
                logger.info(f"Skipping {object_key}: File is not in 'stage/' folder.")
                continue

            original_file_name = object_key.replace("stage/", "")

            # Determine target table and column mapping
            target_config = get_target_table(original_file_name)
            if not target_config:
                logger.info(f"Skipping {object_key}: No matching configuration found.")
                continue

            target_table = target_config['table']
            has_header = target_config['has_header']
            column_definitions = target_config['columns']
            column_names = list(column_definitions.keys())
            logger.info(f"Loading {object_key} into table {target_table}")

            # Generate a new file name with timestamp
            timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
            new_file_name = f"{original_file_name.rsplit('.', 1)[0]}_{timestamp}.csv"
            new_object_key = f"{target_table}/{new_file_name}"

            # Move the file within S3
            s3.copy_object(Bucket=bucket_name, CopySource=f"{bucket_name}/{object_key}", Key=new_object_key)
            s3.delete_object(Bucket=bucket_name, Key=object_key)
            logger.info(f"Renamed and moved {object_key} to {new_object_key}")

            # Download file from S3
            response = s3.get_object(Bucket=bucket_name, Key=new_object_key)
            csv_content = response['Body'].read().decode('utf-8')

            # Read CSV file using pandas
            df = pd.read_csv(StringIO(csv_content), names=column_names, header=0 if has_header else None)

            # Convert 'datetime' columns to datetime64[ns]
            for col in df.columns:
                if "datetime" in col.lower():
                    df[col] = pd.to_datetime(df[col], utc=True)

            # Add metadata fields (file name, timestamp, row number)
            df['load_file_name'] = new_file_name
            df['load_timestamp'] = pd.Timestamp.utcnow()
            df['load_timestamp'] = pd.to_datetime(df['load_timestamp'], utc=True).dt.tz_localize(None)
            df['load_row_number'] = df.index + 1

            engine = create_engine("postgresql://admin:admin@postgres_db:5432/db_raw")
            df.to_sql(target_table, engine, schema = 'stage', if_exists="replace", index=False)

            logger.info(f"Successfully imported {new_object_key} into {target_table}")

        return {'statusCode': 200, 'body': json.dumps("File processed and imported successfully!")}

    except Exception as e:
        logger.error(f"Error processing file: {str(e)}")
        return {'statusCode': 500, 'body': json.dumps(f"Error processing file: {str(e)}")}
