# Deploying to DigitalOcean Kubernetes

This project includes a Helm chart and GitHub Actions workflow for automated deployment to a DigitalOcean Kubernetes (DOKS) cluster. Pushing to `main` triggers a build and deploy automatically.

## Prerequisites

On your DOKS cluster, ensure you have:

1. **Gateway API CRDs** installed:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
   ```
2. **A Gateway API implementation** (e.g. Envoy Gateway, Cilium, NGINX Gateway Fabric)
3. **A Gateway resource** named `public-gateway` with an HTTPS listener
4. **cert-manager** installed with a `ClusterIssuer` named `letsencrypt-prod`

## GitHub Secrets

Configure these in your repo under **Settings > Secrets and variables > Actions**:

| Secret | Description |
|--------|-------------|
| `DIGITALOCEAN_ACCESS_TOKEN` | DO API token with read/write access |
| `DOKS_CLUSTER_NAME` | Name of your DOKS cluster |
| `HELM_EXTRA_ARGS` | Extra Helm flags (see below) |

## Database Secret

Create a Kubernetes secret with your DO managed Postgres connection string:

```bash
kubectl create namespace hikma

kubectl create secret generic hikma-db-secret -n hikma \
  --from-literal=DATABASE_URL="postgresql://user:password@host:25060/dbname?sslmode=require"
```

Then set `HELM_EXTRA_ARGS` in GitHub Secrets to:

```
--set existingSecret=hikma-db-secret
```

## How It Works

1. Push to `dev` triggers CI (tests). On success, `dev` auto-merges to `main`.
2. Push to `main` triggers the deploy workflow:
   - Builds the Docker image and pushes to GitHub Container Registry (GHCR)
   - Deploys to DOKS via `helm upgrade --install`
3. The app runs database migrations automatically on startup before serving traffic.

## Manual Deployment

```bash
helm upgrade --install hikma helm/hikma-health-server/ \
  --namespace hikma \
  --create-namespace \
  --set image.tag=latest \
  --set existingSecret=hikma-db-secret \
  --set gateway.enabled=true
```

## GHCR Image Visibility

The Docker image is pushed to `ghcr.io/<org>/hikma-health-server`. If the GHCR package is **private**, create an image pull secret on your cluster:

```bash
kubectl create secret docker-registry ghcr-credentials -n hikma \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-pat-with-read:packages>
```

Then add to `HELM_EXTRA_ARGS`:

```
--set existingSecret=hikma-db-secret --set imagePullSecrets[0].name=ghcr-credentials
```

## Helm Chart Values

The full set of configurable values is in [`helm/hikma-health-server/values.yaml`](helm/hikma-health-server/values.yaml). Key options:

| Value | Default | Description |
|-------|---------|-------------|
| `gateway.enabled` | `false` | Enable HTTPRoute + TLS Certificate |
| `gateway.gatewayName` | `public-gateway` | Name of the existing Gateway resource |
| `gateway.hostname` | `health.glia.org` | Hostname for routing and TLS |
| `existingSecret` | `""` | Use a pre-created K8s secret for DATABASE_URL |
| `persistence.enabled` | `false` | Enable PVC for photo storage |
| `autoscaling.enabled` | `false` | Enable HPA (2-5 replicas) |
| `networkPolicy.enabled` | `false` | Restrict pod ingress/egress |
| `podDisruptionBudget.enabled` | `false` | Enable PDB (minAvailable: 1) |
