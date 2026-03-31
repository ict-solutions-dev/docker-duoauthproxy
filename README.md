# Docker DuoAuthProxy

[![Docker Image Publish](https://github.com/ict-solutions-dev/docker-duoauthproxy/actions/workflows/docker.yml/badge.svg)](https://github.com/ict-solutions-dev/docker-duoauthproxy/actions/workflows/docker.yml)
[![GitHub release](https://img.shields.io/github/v/release/ict-solutions-dev/docker-duoauthproxy)](https://github.com/ict-solutions-dev/docker-duoauthproxy/releases)

Production-ready Docker image for [Duo Security Authentication Proxy](https://duo.com/docs/authproxy-reference) with RADIUS support. Built for `linux/amd64` and `linux/arm64` on Ubuntu 24.04.

## Quick Start

```bash
docker run -d \
  --name duoauthproxy \
  -p 1812:1812/udp \
  -e RADIUS_HOST=10.10.10.2 \
  -e RADIUS_SECRET=radiussecret \
  -e DUO_IKEY=DIXXXXXXXXXXXXXXXXXX \
  -e DUO_SKEY=YourSecretKeyHere \
  -e DUO_API_HOST=api-XXXXXXXX.duosecurity.com \
  -e RADIUS_CLIENT_IP_1=192.168.1.10 \
  -e RADIUS_CLIENT_SECRET_1=clientsecret \
  ghcr.io/ict-solutions-dev/duoauthproxy:edge-duo6.6.0
```

## Docker Compose

```yaml
services:
  duoauthproxy:
    image: ghcr.io/ict-solutions-dev/duoauthproxy:1.2.0-duo6.6.0
    container_name: duoauthproxy
    restart: unless-stopped
    ports:
      - "1812:1812/udp"
    environment:
      RADIUS_HOST: 10.10.10.2
      RADIUS_SECRET_FILE: /run/secrets/radius_secret
      DUO_IKEY_FILE: /run/secrets/duo_ikey
      DUO_SKEY_FILE: /run/secrets/duo_skey
      DUO_API_HOST: api-XXXXXXXX.duosecurity.com
      RADIUS_CLIENT_IP_1: 192.168.1.10
      RADIUS_CLIENT_SECRET_FILE: /run/secrets/radius_client_secret
      RADIUS_FAILMODE: safe
    secrets:
      - radius_secret
      - duo_ikey
      - duo_skey
      - radius_client_secret
    volumes:
      - duoauthproxy-logs:/opt/duoauthproxy/log

secrets:
  radius_secret:
    file: ./secrets/radius_secret.txt
  duo_ikey:
    file: ./secrets/duo_ikey.txt
  duo_skey:
    file: ./secrets/duo_skey.txt
  radius_client_secret:
    file: ./secrets/radius_client_secret.txt

volumes:
  duoauthproxy-logs:
```

## Configuration

### Required Environment Variables

| Variable | Description |
| --- | --- |
| `RADIUS_HOST` | Primary RADIUS server hostname or IP |
| `RADIUS_SECRET` | RADIUS server shared secret |
| `DUO_IKEY` | Duo integration key |
| `DUO_SKEY` | Duo secret key |
| `DUO_API_HOST` | Duo API hostname (e.g. `api-XXXXXXXX.duosecurity.com`) |
| `RADIUS_CLIENT_IP_1` | First RADIUS client IP address |
| `RADIUS_CLIENT_SECRET_1` | First RADIUS client shared secret |

### Optional Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `RADIUS_PORT` | `1812` | Upstream RADIUS server port |
| `RADIUS_SERVER_PORT` | `1812` | Local RADIUS listener port |
| `RADIUS_CLIENT_TYPE` | `radius_client` | Auth client type — `radius_client`, `ad_client`, or `duo_only_client` |
| `RADIUS_FAILMODE` | `safe` | Behavior when Duo is unreachable — `safe` (allow) or `secure` (deny) |
| `RADIUS_PASS_THROUGH_ALL` | `false` | Forward all RADIUS attributes to the client |
| `RADIUS_PASS_THROUGH_ATTRS` | — | Comma-separated attribute names to forward (e.g. `Framed-IP-Address,Reply-Message`) |

### Multiple RADIUS Servers (up to 6)

Configure additional upstream RADIUS servers using sequentially numbered variables:

| Variable | Description |
| --- | --- |
| `RADIUS_HOST_2` … `RADIUS_HOST_6` | Additional RADIUS server hostnames/IPs |
| `RADIUS_PORT_2` … `RADIUS_PORT_6` | Ports for additional servers (default: `1812`) |

> **Note:** Hosts must be defined sequentially — you cannot define `RADIUS_HOST_4` without `RADIUS_HOST_2` and `RADIUS_HOST_3`.

### Multiple RADIUS Clients (up to 6)

| Variable | Description |
| --- | --- |
| `RADIUS_CLIENT_IP_2` … `RADIUS_CLIENT_IP_6` | Additional client IPs |
| `RADIUS_CLIENT_SECRET_2` … `RADIUS_CLIENT_SECRET_6` | Corresponding client secrets |

### Docker Secrets Support

Every environment variable that contains sensitive data supports the `_FILE` suffix pattern for use with Docker secrets or mounted files:

```bash
# Instead of passing the secret directly:
-e RADIUS_SECRET=mysecret

# Mount a file and reference it:
-e RADIUS_SECRET_FILE=/run/secrets/radius_secret
```

If both `VAR` and `VAR_FILE` are set, the container will exit with an error.

## DNS Variant

The standard Duo Authentication Proxy only accepts IP addresses for the `RADIUS_HOST` parameter. The `-dns` image variant patches the proxy to also accept DNS hostnames, which is useful in Docker Swarm or Compose environments where services are referenced by name.

```yaml
services:
  duoauthproxy:
    image: ghcr.io/ict-solutions-dev/duoauthproxy:1.2.0-duo6.6.0-dns
    environment:
      RADIUS_HOST: nps-server  # Docker service name instead of IP
```

The DNS variant resolves hostnames to IP addresses at container startup. The resolved IP is used for all subsequent RADIUS communication.

> **Note:** DNS resolution happens once at startup. If the target service IP changes (e.g. container reschedule), the proxy container must be restarted. In Docker Swarm this is typically not an issue since service VIPs are stable.

To build the DNS variant locally:

```bash
docker build --build-arg DUO_VERSION=6.6.0 --build-arg ENABLE_DNS_PATCH=true -t duoauthproxy:dns .
```

## Exposed Ports

| Port | Protocol | Purpose |
| --- | --- | --- |
| `1812–1818` | UDP | RADIUS authentication |
| `18120` | UDP | Duo Authentication Proxy |
| `636` | TCP | LDAPS |
| `389` | TCP | LDAP |

## Volumes

| Path | Purpose |
| --- | --- |
| `/opt/duoauthproxy/conf/` | Configuration directory (generated at startup) |
| `/opt/duoauthproxy/log/` | Application logs |

## How It Works

The entrypoint script ([`assets/01-init.sh`](assets/01-init.sh)) performs the following on container startup:

1. **Secret file resolution** — reads `*_FILE` environment variables from mounted files
2. **Input validation** — checks required variables, sequential host ordering, valid client types and failmodes
3. **Config generation** — writes `/opt/duoauthproxy/conf/authproxy.cfg` from environment variables
4. **Connectivity test** — runs `authproxy_connectivity_tool` to verify Duo API reachability
5. **Startup** — launches the authentication proxy daemon via `exec`

Secrets are redacted in the startup log output.

## Versioning

This project uses a **dual version scheme** — the image tag contains both the project version and the upstream Duo Authentication Proxy version:

```
ghcr.io/ict-solutions-dev/duoauthproxy:1.2.0-duo6.6.0
                                        ^^^^^     ^^^^^
                                        project   Duo upstream
```

| Change | Bump | Example |
| --- | --- | --- |
| Breaking change (renamed env vars, new entrypoint) | **Major** | `v1.x.x` → `v2.0.0` |
| New feature (RadSec support, new env vars) | **Minor** | `v1.1.0` → `v1.2.0` |
| Bugfix, Duo version bump, base image update | **Patch** | `v1.2.0` → `v1.2.1` |

## Image Tags

Images are published to [GitHub Container Registry](https://github.com/ict-solutions-dev/docker-duoauthproxy/pkgs/container/duoauthproxy).

| Tag Pattern | Source | Example |
| --- | --- | --- |
| `edge-duo{VERSION}` | `develop` branch | `edge-duo6.6.0` |
| `{RELEASE}-duo{VERSION}` | Git tag (`v*`) | `1.2.0-duo6.6.0` |
| `edge-duo{VERSION}-dns` | `develop` branch (DNS variant) | `edge-duo6.6.0-dns` |
| `{RELEASE}-duo{VERSION}-dns` | Git tag (`v*`, DNS variant) | `1.2.0-duo6.6.0-dns` |

```bash
# Development (latest from develop branch)
docker pull ghcr.io/ict-solutions-dev/duoauthproxy:edge-duo6.6.0

# Production release
docker pull ghcr.io/ict-solutions-dev/duoauthproxy:1.2.0-duo6.6.0

# DNS variant (supports hostnames in RADIUS_HOST)
docker pull ghcr.io/ict-solutions-dev/duoauthproxy:1.2.0-duo6.6.0-dns
```

Only the latest Duo version is actively built. Older images remain available in GHCR but are no longer rebuilt.

## CI/CD Pipeline

The [GitHub Actions workflow](.github/workflows/docker.yml) runs on push to `develop`, version tags (`v*`), and manual dispatch. The Duo version is defined as `DUO_VERSION` env in the workflow file.

The pipeline:

1. **Lints** the Dockerfile with [hadolint](https://github.com/hadolint/hadolint)
2. **Builds** multi-arch images (`linux/amd64`, `linux/arm64`) using Docker Buildx
3. **Pushes** to GitHub Container Registry
4. **Scans** for vulnerabilities with [Trivy](https://github.com/aquasecurity/trivy) (results uploaded to Security tab)
5. **Generates** SBOM in SPDX format via [Anchore](https://github.com/anchore/sbom-action)
6. **Attests** build provenance with [GitHub Attestations](https://github.com/actions/attest-build-provenance)

## Security

- Container runs as non-root user `duo` (UID/GID `35505`)
- Trivy vulnerability scanning on every build
- SBOM generation for supply chain transparency
- Build provenance attestation via Sigstore
- Docker secrets support to avoid plaintext credentials
- Dependabot enabled for Docker base image and GitHub Actions updates

## Contributing

This repository enforces [Conventional Commits](https://www.conventionalcommits.org/) for PR titles via [prlint](https://github.com/ewolfe/prlint). Valid prefixes: `feat`, `fix`, `chore`, `docs`, `perf`, `refactor`, `style`, `test`, `lang`.

## License

See repository for license details.
