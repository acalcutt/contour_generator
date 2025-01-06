# Use an official Node.js runtime as a parent image
FROM node:22-slim AS builder

# Set the working directory in the container
WORKDIR /app

# Copy the application files to the container
COPY . .

# Install dependencies
RUN npm install

RUN npm i -g npm@latest

# Create a new stage for the final image
FROM node:22-slim

# Copy all files from the builder stage
COPY --from=builder /app /app
WORKDIR /app

# Install bc
RUN apt-get update && apt-get install -y bc

# Create folder for data mapping
RUN mkdir -p /data && chown node:node /data
VOLUME /data

# Make the shell script executable
RUN chmod +x /app/generate_all_tiles_at_zoom.sh

# Entrypoint to allow running commands
ENTRYPOINT ["/bin/bash", "-c"]

