# Stage 1: Install dependencies
FROM node:22.14.0-slim AS deps

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Stage 2: Build the application
FROM node:22.14.0-slim AS build

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm run build

# Stage 3: Production image
FROM node:22.14.0-slim AS production

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy package files and install full deps (dev deps needed for migrations/recovery scripts)
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy built output and source files needed at runtime
COPY --from=build /app/.output ./.output
COPY --from=build /app/db ./db
COPY --from=build /app/scripts ./scripts
COPY --from=build /app/src/db ./src/db
COPY --from=build /app/src/env.ts ./src/env.ts
COPY --from=build /app/tsconfig.json ./tsconfig.json
COPY --from=build /app/kysely.config.ts ./kysely.config.ts

# Create photos directory and set ownership
RUN mkdir -p /app/photos && chown -R node:node /app

USER node

EXPOSE 3000

CMD ["pnpm", "run", "start"]
