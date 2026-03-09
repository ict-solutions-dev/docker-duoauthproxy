# Supported Duo Authentication Proxy Versions

This file drives the CI/CD build matrix. Each version listed below triggers a separate Docker image build in the [GitHub Actions workflow](.github/workflows/docker.yml).

To add a new version, append it to the list below and push to `develop`. The pipeline will automatically build and publish images for all listed versions.

> **Format:** One version per line, prefixed with `- `. The workflow parses this file directly.

- 6.4.2
- 6.5.0
- 6.5.1
- 6.5.2
