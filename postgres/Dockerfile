FROM postgres:latest

# Install s3fs, fuse, and curl
RUN apt-get update && apt-get install -y s3fs fuse curl

# Ensure FUSE is accessible
RUN mkdir -p /dev/fuse && chmod 666 /dev/fuse

# Create the init script directory
RUN mkdir -p /docker-entrypoint-initdb.d

# Copy init SQL scripts
COPY ./init-postgres/init-database.sql /docker-entrypoint-initdb.d/

# Ensure scripts have execution permissions
RUN chmod 644 /docker-entrypoint-initdb.d/*.sql

# Use the default PostgreSQL entrypoint
CMD ["postgres"]