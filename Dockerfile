# Multi-stage Dockerfile for BrettAppsCode Node.js Application
# Optimized for production deployment to Azure

# Stage 1: Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including devDependencies for potential build steps)
RUN npm ci

# Copy application source
COPY . .

# Run any build steps if needed
RUN npm run build --if-present || echo "No build step defined"

# Stage 2: Production stage
FROM node:18-alpine

# Add metadata
LABEL maintainer="Brett Anthony Sjoberg"
LABEL description="BrettAppsCode - AI-powered code editor with live preview"
LABEL version="1.0.0"

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application files from builder
COPY --from=builder /app/server.js ./
COPY --from=builder /app/setup-codemirror.js ./
COPY --from=builder /app/public ./public

# Create uploads directory with proper permissions
RUN mkdir -p /app/uploads && \
    chmod 755 /app/uploads

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000

# Start the application
CMD ["node", "server.js"]
