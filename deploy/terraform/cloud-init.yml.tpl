#cloud-config

packages:
  - docker.io
  - docker-compose-v2

runcmd:
  - systemctl enable --now docker
  - mkdir -p /opt/cloudrift-runner
  - |
    cat > /opt/cloudrift-runner/.env <<'ENVEOF'
    CLOUDRIFT_API_KEY=${cloudrift_api_key}
    GITHUB_PAT=${github_pat}
    GITHUB_WEBHOOK_SECRET=${github_webhook_secret}
    DOMAIN=${domain}
    CLOUDRIFT_API_URL=${cloudrift_api_url}
    CLOUDRIFT_WITH_PUBLIC_IP=${cloudrift_with_public_ip}
    RUNNER_LABEL=${runner_label}
    MAX_RUNNER_LIFETIME_MINUTES=${max_runner_lifetime_minutes}
    ENVEOF
  - chmod 600 /opt/cloudrift-runner/.env
  - cd /opt/cloudrift-runner && git clone https://github.com/cloudrift/cloudrift-github-runner.git repo
  - cd /opt/cloudrift-runner/repo && cp /opt/cloudrift-runner/.env .env
  - cd /opt/cloudrift-runner/repo && docker compose up -d --build
