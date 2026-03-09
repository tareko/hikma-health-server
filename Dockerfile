# Stage 1: Build
FROM node:22.14-alpine AS builder

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build the application
RUN pnpm build

# Stage 2: Production
FROM node:22.14-alpine AS production

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install all dependencies (migrations and recovery scripts require dev deps like dotenv-cli and tsx)
RUN pnpm install --frozen-lockfile

# Copy built application from builder stage
COPY --from=builder /app/.output .output
COPY --from=builder /app/public public
COPY --from=builder /app/db db

# Copy scripts and source files needed for migrations and recovery
# Models have deep imports across src/ (db, lib, data, etc.), so copy all of src/
COPY --from=builder /app/scripts scripts
COPY --from=builder /app/src src

# Copy config files
COPY kysely.config.ts .
COPY tsconfig.json .

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) })"

# Start the application
CMD ["pnpm", "start"]
