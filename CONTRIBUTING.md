# Contributing

Contributions are welcome. This document outlines the process and conventions.

## Getting Started

1. Fork the repository
2. Create a feature branch from `develop`
3. Make your changes
4. Submit a pull request against `develop`

## Branch Strategy

- `develop` — active development, triggers `edge-*` image builds
- `main` — not used for direct development
- Version tags (`v*`) — trigger release image builds

## Commit and PR Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/). PR titles are validated via [prlint](https://github.com/ewolfe/prlint).

Valid prefixes:

| Prefix | Usage |
| --- | --- |
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Maintenance, dependencies |
| `refactor` | Code restructuring without behavior change |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `style` | Formatting, whitespace |
| `lang` | Translations |

Examples:

```
feat: add support for LDAP client type
fix: handle missing RADIUS_PORT gracefully
docs: update environment variable reference
```

## Adding a New Duo Version

1. Add the version number to [`SUPPORTED_VERSIONS.md`](SUPPORTED_VERSIONS.md)
2. The CI pipeline will automatically build images for all listed versions

## Dockerfile Changes

- The Dockerfile is linted with [hadolint](https://github.com/hadolint/hadolint) in CI
- Use `# hadolint ignore=DLXXXX` for intentional rule suppressions with a comment explaining why

## Code Style

- Shell scripts: follow existing patterns in [`assets/01-init.sh`](assets/01-init.sh)
- Use `shellcheck` conventions where possible
- Variable names, function names, comments, and error messages in English

## Review Process

All pull requests require review from [@jozefrebjak](https://github.com/jozefrebjak) (see [`CODEOWNERS`](.github/CODEOWNERS)).
