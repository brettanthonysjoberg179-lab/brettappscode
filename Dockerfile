# Multi-stage build for brettappscode Node.js application

# Stage 1: Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including devDependencies for build)
RUN npm ci

# Copy application source
COPY . .

# Run postinstall script (setup-codemirror.js)
RUN npm run postinstall --if-present

# Remove dev dependencies
RUN npm prune --production

# Stage 2: Production stage
FROM node:18-alpine

# Set environment to production
ENV NODE_ENV=production
ENV PORT=3000

# Create app directory
WORKDIR /app

# Copy only production node_modules from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy package.json for metadata
COPY package*.json ./

# Copy application files
COPY server.js ./
COPY setup-codemirror.js ./
COPY public ./public

# Create uploads directory with proper permissions
RUN mkdir -p /app/uploads && chmod 755 /app/uploads

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership of app directory
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose the application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application
CMD ["node", "server.js"]
