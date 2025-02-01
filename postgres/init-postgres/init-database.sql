-- Create database "raw"
CREATE DATABASE db_raw;

-- Connect to the "raw" database
\c db_raw;

-- Create schema "stage"
CREATE SCHEMA stage;

CREATE TABLE stage.departments (
    id INTEGER PRIMARY KEY,
    department_name VARCHAR(255) NOT NULL,
    load_file_name VARCHAR(255) NOT NULL,
    load_timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    load_row_number INTEGER NOT NULL
);

CREATE TABLE stage.jobs (
    id INTEGER PRIMARY KEY,
    job_name VARCHAR(255) NOT NULL,
    load_file_name VARCHAR(255) NOT NULL,
    load_timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    load_row_number INTEGER NOT NULL
);

CREATE TABLE stage.hired_employees (
    id INTEGER PRIMARY KEY,
    employee_name VARCHAR(255) NOT NULL,
    hire_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    department_id INTEGER NOT NULL,
    job_id INTEGER NOT NULL,
    load_file_name VARCHAR(255) NOT NULL,
    load_timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    load_row_number INTEGER NOT NULL
);
