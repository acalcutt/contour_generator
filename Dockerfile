# Use an official Node.js runtime as a parent image
FROM node:22-slim AS builder

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json first
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy the application files to the container
COPY . .

# Create a new stage for the final image
FROM node:22-slim

# Install bc and upgrade npm (as root)
RUN apt-get update && apt-get install -y bc
RUN npm i -g npm@latest

# Create folder for data mapping and set ownership (as root)
RUN mkdir -p /data
VOLUME /data

# Copy all files from the builder stage
COPY --from=builder /app /app
WORKDIR /app

# Make the shell script executable (as root)
RUN chmod +x /app/generate_tiles.sh

# Entrypoint to allow running commands
ENTRYPOINT ["/app/generate_tiles.sh"]
