# NetBird Helm Chart

Helm chart for deploying [NetBird](https://github.com/netbirdio/netbird) - a WireGuard-based mesh VPN platform.

This chart supports both unified server mode (recommended) and microservice mode for flexible deployments.

> **Note:** This chart is based on [totmicro/helms](https://github.com/totmicro/helms).

## Features

- **Unified Server Mode** - Single deployment with management, signal, and relay services
- **Microservice Mode** - Separate deployments for management, signal, and relay
- **Dashboard** - Web UI for managing peers and networks
- **Multiple IDP Support** - Auth0, Google, Okta, Authentik, and more
- **Persistent Storage** - SQLite, PostgreSQL, or MySQL backends
- **Ingress Configuration** - HTTP and gRPC ingress support
- **Prometheus Metrics** - Optional ServiceMonitor for Prometheus Operator

## Add Repository

```console
helm repo add netbird https://arsolitt.github.io/netbird-helm
helm repo update
```

## TL;DR

```console
helm install netbird netbird/netbird
```

## Installing the Chart

To install the chart with the release name `my-release`:

```console
helm install my-release netbird/netbird
```

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
helm uninstall my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

For detailed configuration options, see the [chart README](charts/netbird/README.md).

### Quick Start

The chart deploys in unified server mode by default with SQLite storage:

```yaml
server:
  enabled: true
  config:
    exposedAddress: "https://netbird.example.com"
    auth:
      issuer: "https://your-idp.example.com"

dashboard:
  enabled: true
```

## Examples

See [charts/netbird/examples/](charts/netbird/examples/) for complete deployment examples:

- **nginx-ingress/** - Examples with Auth0, Google, Okta, Authentik (microservice mode)
- **traefik-ingress/** - Authentik example with Traefik (microservice mode)

## Releasing New Chart Versions

New chart versions are automatically published through [GitHub Actions](./.github/workflows/release.yml). To deploy a new version, increment the chart version in `Chart.yaml`.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Credits

Based on [totmicro/helms](https://github.com/totmicro/helms).

## Additional Resources

- [NetBird Documentation](https://docs.netbird.io/)
- [NetBird GitHub](https://github.com/netbirdio/netbird)
