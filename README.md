# Docker DuoAuthProxy

[![Docker Image Publish](https://github.com/ict-solutions-dev/docker-duoauthproxy/actions/workflows/docker.yml/badge.svg)](https://github.com/ict-solutions-dev/docker-duoauthproxy/actions/workflows/docker.yml)

Docker image for Duo Security Authentication Proxy with RADIUS support.

## Environment Variables

### Required Variables

| Variable | Description |
|----------|-------------|
| `RADIUS_HOST` | Primary RADIUS server hostname/IP |
| `RADIUS_SECRET` | RADIUS server shared secret |
| `DUO_IKEY` | Duo integration key |
| `DUO_SKEY` | Duo secret key |
| `DUO_API_HOST` | Duo API hostname |
| `RADIUS_CLIENT_IP_1` | RADIUS client IP address |
| `RADIUS_CLIENT_SECRET_1` | RADIUS client shared secret |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RADIUS_PORT` | RADIUS server port | `1812` |
| `RADIUS_SERVER_PORT` | Local RADIUS server port | `1812` |
| `RADIUS_CLIENT_TYPE` | Client type (`radius_client`, `ad_client`, `duo_only_client`) | `radius_client` |
| `RADIUS_FAILMODE` | Failmode (`safe`, `secure`) | `safe` |
| `RADIUS_PASS_THROUGH_ALL` | Pass through all attributes | `false` |
| `RADIUS_PASS_THROUGH_ATTRS` | Comma-separated list of attributes to pass through | - |

### Additional RADIUS Servers

You can configure up to 5 additional RADIUS servers using:

| Variable | Description |
|----------|-------------|
| `RADIUS_HOST_2` to `RADIUS_HOST_6` | Additional RADIUS server hostnames |
| `RADIUS_PORT_2` to `RADIUS_PORT_6` | Ports for additional servers (defaults to 1812) |
| `RADIUS_SECRET_2` to `RADIUS_SECRET_6` | Secrets for additional servers (defaults to primary secret) |

### Additional RADIUS Clients

Support for multiple RADIUS clients:

| Variable | Description |
|----------|-------------|
| `RADIUS_CLIENT_IP_2` to `RADIUS_CLIENT_IP_6` | Additional client IPs |
| `RADIUS_CLIENT_SECRET_2` to `RADIUS_CLIENT_SECRET_6` | Secrets for additional clients |

## Usage

Basic docker run command:

```console
docker run -d \
  -e RADIUS_HOST=radius.example.com \
  -e RADIUS_SECRET=radiussecret \
  -e DUO_IKEY=YOUR_IKEY \
  -e DUO_SKEY=YOUR_SKEY \
  -e DUO_API_HOST=api-xyz.duosecurity.com \
  -e RADIUS_CLIENT_IP_1=192.168.1.10 \
  -e RADIUS_CLIENT_SECRET_1=clientsecret \
  ictsolutions/duoauthproxy
```

# Version Management

## Image Versioning Strategy

Images are built automatically using the following schema:
- `edge-duo{VERSION}` - Development builds from `develop` branch
- `{RELEASE}-duo{VERSION}` - Release builds from tags (e.g. `v1.0.0-duo6.4.2`)

Where:
- `{RELEASE}` comes from Git tags (e.g. `v1.0.0`)
- `{VERSION}` comes from `SUPPORTED_VERSIONS.md`

## Supported Versions

Supported DuoAuthProxy versions are maintained in `SUPPORTED_VERSIONS.md`. Images are automatically built for each listed version.

## Image Tags

Examples:
```console
ghcr.io/ict-solutions-dev/duoauthproxy:edge-duo6.4.2     # Latest development build
ghcr.io/ict-solutions-dev/duoauthproxy:1.0.0-duo6.4.2    # Release 1.0.0 with Duo 6.4.2
```

## Build Process

1. GitHub Actions trigger on:
   - Push to `develop` branch
   - New version tags (`v*`)
   - Manual workflow dispatch

2. Build matrix is created from:
   - All versions in  SUPPORTED_VERSIONS.md
   - Or specific version via manual trigger

3. For each version:
   - Builds Docker image with specified Duo version
   - Tags image with appropriate version scheme
   - Pushes to GitHub Container Registry
