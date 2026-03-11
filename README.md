# cloudrift-github-runner

Docker-compose deployable controller for ephemeral GitHub Actions runners on [CloudRift](https://cloudrift.ai) VMs. Provision GPU-enabled self-hosted runners on demand — VMs are created when jobs are queued and terminated when they complete.

## How It Works

1. A GitHub Actions workflow requests a `cloudrift`-labeled runner
2. GitHub sends a `workflow_job` webhook to the controller (Flask app behind Caddy)
3. The controller checks GPU availability, provisions a CloudRift VM with a JIT runner, and stores state in SQLite
4. The runner picks up the job, executes it, and shuts down
5. On the `completed` webhook, the controller terminates the VM
6. A background scheduler cleans up any orphaned VMs every 10 minutes

## Quick Start

### Prerequisites

- Docker and Docker Compose
- [CloudRift](https://cloudrift.ai) account and API key
- GitHub PAT with `administration:write` scope (for runner registration)
- A domain name with DNS pointing to your server (for automatic TLS)

### Deploy

```bash
# 1. Clone and configure
cp .env.example .env
# Edit .env with your secrets and domain

# 2. Start services
make docker-up

# 3. Verify
curl https://your-domain.com/health
```

### Deploy with Terraform (GCP VM)

```bash
# 1. Initialize Terraform
make deploy-init

# 2. Deploy (provisions VM, installs Docker, starts containers)
make deploy
```

Terraform will prompt for `project_id`, `domain`, and sensitive variables. To skip prompts, create `deploy/terraform/terraform.tfvars`:

```hcl
project_id            = "my-gcp-project"
domain                = "runners.example.com"
cloudrift_api_key     = "your-key"
github_pat            = "ghp_xxx"
github_webhook_secret = "your-secret"
```

### Configure GitHub Webhook

1. Go to your repo (or org) Settings > Webhooks > Add webhook
2. Set the Payload URL to `https://your-domain.com/webhook`
3. Set Content type to `application/json`
4. Set the Secret to the same value as `GITHUB_WEBHOOK_SECRET`
5. Select "Workflow jobs" under events

### Use in a Workflow

```yaml
jobs:
  gpu-test:
    runs-on: [self-hosted, cloudrift]
    steps:
      - uses: actions/checkout@v4
      - run: nvidia-smi
```

## Per-Repo Configuration (Required)

Each repo that uses CloudRift runners **must** have a `.cloudrift-runner.yml` in the repo root. Both `instance_type` and `image_url` are required — there are no env var fallbacks for these.

```yaml
defaults:
  instance_type: generic-gpu.1
  with_public_ip: true  # default is false
  image_url: https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

jobs:
  gpu-test:
    instance_type: gpu.a100-80
  training:
    instance_type: gpu.h100-80
    image_url: https://storage.googleapis.com/.../rocm-ubuntu-24.04.img
```

- `defaults.instance_type` and `defaults.image_url` are required (unless every job has its own overrides)
- Jobs not listed under `jobs:` use the `defaults` section
- Per-job entries can override `instance_type`, `image_url`, and `with_public_ip`
- If no config file exists, the job is skipped (no runner provisioned)

## Configuration

| Env Var                       | Description                  | Default                    |
|-------------------------------|------------------------------|----------------------------|
| `CLOUDRIFT_API_KEY`           | CloudRift API key            | required                   |
| `CLOUDRIFT_API_URL`           | CloudRift API base URL       | `https://api.cloudrift.ai` |
| `CLOUDRIFT_WITH_PUBLIC_IP`    | Default public IP setting    | `false`                    |
| `RUNNER_LABEL`                | Label to match               | `cloudrift`                |
| `MAX_RUNNER_LIFETIME_MINUTES` | VM auto-shutdown timeout     | `120`                      |
| `GITHUB_PAT`                  | GitHub PAT                   | required                   |
| `GITHUB_WEBHOOK_SECRET`       | Webhook HMAC secret          | required                   |
| `DOMAIN`                      | Domain for TLS (Caddy)       | required                   |
| `DATABASE_URL`                | SQLAlchemy database URL      | `sqlite:////app/data/runner_jobs.db` |

## Architecture

- **Flask + Gunicorn**: Single-worker, 4-thread web server on port 8080
- **Caddy**: Reverse proxy with automatic Let's Encrypt TLS on ports 80/443
- **SQLite**: Job state storage (persisted via Docker volume)
- **APScheduler**: Background cleanup every 10 minutes + TTL cleanup every hour

## Development

```bash
make setup        # create venv + install deps
make test         # run tests
make lint         # check linting + formatting
make fmt          # auto-fix formatting
```

## License

Apache 2.0
