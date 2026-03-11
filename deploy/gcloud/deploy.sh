#!/usr/bin/env bash
#
# Deploy cloudrift-github-runner Cloud Functions using gcloud CLI.
# Alternative to Terraform for quick deployments.
#
# Prerequisites:
#   - gcloud CLI authenticated with appropriate permissions
#   - Secrets already created in Secret Manager
#
# Usage:
#   export GCP_PROJECT=my-project
#   export GCP_REGION=us-central1
#   ./deploy.sh
#
set -euo pipefail

PROJECT="${GCP_PROJECT:?Set GCP_PROJECT}"
REGION="${GCP_REGION:-us-central1}"
SA_NAME="cloudrift-runner"
SA_EMAIL="${SA_NAME}@${PROJECT}.iam.gserviceaccount.com"

CLOUDRIFT_API_URL="${CLOUDRIFT_API_URL:-https://api.cloudrift.ai}"
CLOUDRIFT_WITH_PUBLIC_IP="${CLOUDRIFT_WITH_PUBLIC_IP:-false}"
RUNNER_LABEL="${RUNNER_LABEL:-cloudrift}"
MAX_RUNNER_LIFETIME_MINUTES="${MAX_RUNNER_LIFETIME_MINUTES:-120}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "==> Creating service account (if not exists)..."
gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" 2>/dev/null || \
  gcloud iam service-accounts create "$SA_NAME" \
    --project="$PROJECT" \
    --display-name="CloudRift GitHub Runner Controller"

echo "==> Granting IAM roles..."
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/datastore.user" \
  --condition=None --quiet

for SECRET in cloudrift-runner-api-key cloudrift-runner-github-pat cloudrift-runner-webhook-secret; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --project="$PROJECT" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor" \
    --quiet 2>/dev/null || true
done

ENV_VARS="CLOUDRIFT_API_URL=$CLOUDRIFT_API_URL"
ENV_VARS+=",CLOUDRIFT_WITH_PUBLIC_IP=$CLOUDRIFT_WITH_PUBLIC_IP"
ENV_VARS+=",RUNNER_LABEL=$RUNNER_LABEL"
ENV_VARS+=",MAX_RUNNER_LIFETIME_MINUTES=$MAX_RUNNER_LIFETIME_MINUTES"

SECRET_VARS="CLOUDRIFT_API_KEY=cloudrift-runner-api-key:latest"
SECRET_VARS+=",GITHUB_PAT=cloudrift-runner-github-pat:latest"
SECRET_VARS+=",GITHUB_WEBHOOK_SECRET=cloudrift-runner-webhook-secret:latest"

echo "==> Deploying webhook handler..."
gcloud functions deploy cloudrift-runner-webhook \
  --gen2 \
  --project="$PROJECT" \
  --region="$REGION" \
  --runtime=python311 \
  --entry-point=handle_webhook \
  --source="$REPO_ROOT" \
  --trigger-http \
  --allow-unauthenticated \
  --service-account="$SA_EMAIL" \
  --memory=256MB \
  --timeout=60s \
  --max-instances=10 \
  --set-env-vars="$ENV_VARS" \
  --set-secrets="$SECRET_VARS"

echo "==> Deploying cleanup handler..."
gcloud functions deploy cloudrift-runner-cleanup \
  --gen2 \
  --project="$PROJECT" \
  --region="$REGION" \
  --runtime=python311 \
  --entry-point=cleanup_orphans_handler \
  --source="$REPO_ROOT" \
  --trigger-http \
  --no-allow-unauthenticated \
  --service-account="$SA_EMAIL" \
  --memory=256MB \
  --timeout=120s \
  --max-instances=1 \
  --set-env-vars="$ENV_VARS" \
  --set-secrets="$SECRET_VARS"

CLEANUP_URL=$(gcloud functions describe cloudrift-runner-cleanup \
  --gen2 --project="$PROJECT" --region="$REGION" \
  --format='value(serviceConfig.uri)')

echo "==> Creating Cloud Scheduler job..."
gcloud scheduler jobs describe cloudrift-runner-cleanup \
  --project="$PROJECT" --location="$REGION" 2>/dev/null && \
  gcloud scheduler jobs update http cloudrift-runner-cleanup \
    --project="$PROJECT" \
    --location="$REGION" \
    --schedule="*/10 * * * *" \
    --uri="$CLEANUP_URL" \
    --http-method=POST \
    --oidc-service-account-email="$SA_EMAIL" || \
  gcloud scheduler jobs create http cloudrift-runner-cleanup \
    --project="$PROJECT" \
    --location="$REGION" \
    --schedule="*/10 * * * *" \
    --uri="$CLEANUP_URL" \
    --http-method=POST \
    --oidc-service-account-email="$SA_EMAIL"

WEBHOOK_URL=$(gcloud functions describe cloudrift-runner-webhook \
  --gen2 --project="$PROJECT" --region="$REGION" \
  --format='value(serviceConfig.uri)')

echo ""
echo "Deployment complete!"
echo "Webhook URL: $WEBHOOK_URL"
echo ""
echo "Next: Configure this URL as a GitHub webhook with:"
echo "  - Content type: application/json"
echo "  - Events: Workflow jobs"
echo "  - Secret: (your GITHUB_WEBHOOK_SECRET value)"
