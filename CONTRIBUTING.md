# Contributing

Thank you for your interest in contributing to cloudrift-github-runner!

## Development Setup

```bash
# Clone the repo
git clone https://github.com/cloudrift/cloudrift-github-runner.git
cd cloudrift-github-runner

# Create a virtual environment and install dev dependencies
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## Running Tests

```bash
pytest -vv
```

## Linting & Formatting

```bash
ruff check src/ tests/
ruff format src/ tests/
```

## Pull Requests

1. Fork the repository and create a feature branch
2. Make your changes with tests
3. Ensure all tests pass and linting is clean
4. Open a PR with a clear description of the change

## Code of Conduct

Be respectful. We're all here to build useful tools.
