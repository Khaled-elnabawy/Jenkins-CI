# Dockerfile for URL Shortener
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev

# Copy application files
COPY . .

# Create directory for SQLite database
RUN mkdir -p /app/data

# Expose port
EXPOSE 3000

# Set environment variable for database path
ENV DB_PATH=/app/data/urls.db

# Start the application
CMD ["node", "server.js"]
