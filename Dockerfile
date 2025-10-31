#=========================================================================
# Multi-stage Dockerfile for Node.js Application
#
# This Dockerfile:
# - Uses multi-stage build to minimize image size
# - Runs as non-root user for security
# - Includes health check
# - Optimized for production use
#=========================================================================

#-------------------------------------------------------------------------
# Stage 1: Build Stage
#-------------------------------------------------------------------------
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

#-------------------------------------------------------------------------
# Stage 2: Production Stage
#-------------------------------------------------------------------------
FROM node:18-alpine

# Build arguments
ARG BUILD_DATE
ARG VERSION
LABEL maintainer="Brett Anthony Sjoberg" \
      org.opencontainers.image.title="BrettAppsCode" \
      org.opencontainers.image.description="AI-powered code editor with live preview" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}"

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy node_modules from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application files
COPY --chown=nodejs:nodejs package*.json ./
COPY --chown=nodejs:nodejs server.js ./
COPY --chown=nodejs:nodejs setup-codemirror.js ./
COPY --chown=nodejs:nodejs public ./public
COPY --chown=nodejs:nodejs .env.example ./.env.example

# Create uploads directory with proper permissions
RUN mkdir -p uploads && \
    chown -R nodejs:nodejs uploads

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Environment variables
ENV NODE_ENV=production \
    PORT=3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "server.js"]
