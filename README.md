# NetBird Helm Chart

Helm chart for deploying [NetBird](https://github.com/netbirdio/netbird) - a WireGuard-based mesh VPN platform.

This chart supports both unified server mode and microservice mode for flexible deployments.

> **Note:** This chart is based on [totmicro/helms](https://github.com/totmicro/helms).

> **Warning:** Unified server mode is currently **unstable** and may not work correctly. Use **microservice mode** for production deployments.

## Features

- **Unified Server Mode** - Single deployment with management, signal, and relay services (⚠️ unstable)
- **Microservice Mode** - Separate deployments for management, signal, and relay (recommended)
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

### Quick Start (Microservice Mode)

Use microservice mode for stable deployments:

```yaml
server:
  enabled: false

management:
  enabled: true
  configmap: |-
    {
      "Signal": { "URI": "netbird.example.com:443" },
      "HttpConfig": { "AuthIssuer": "https://your-idp.example.com" }
    }

signal:
  enabled: true

relay:
  enabled: true

dashboard:
  enabled: true
```

See [examples](charts/netbird/examples/) for complete configurations.

## Examples

See [charts/netbird/examples/](charts/netbird/examples/) for complete deployment examples:

- **nginx-ingress/** - Examples with Auth0, Google, Okta, Authentik (microservice mode)
- **traefik-ingress/** - Authentik example with Traefik (microservice mode)

## Releasing New Chart Versions

New chart versions are automatically published through [GitHub Actions](./.github/workflows/release.yml). To deploy a new version, increment the chart version in `Chart.yaml`.

## TODO / Roadmap

- [ ] **Implement unified server mode support** - The `netbirdio/netbird-server` unified image requires proper configuration and testing. Currently, use microservice mode with separate `management`, `signal`, and `relay` components.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Credits

Based on [totmicro/helms](https://github.com/totmicro/helms).

## Additional Resources

- [NetBird Documentation](https://docs.netbird.io/)
- [NetBird GitHub](https://github.com/netbirdio/netbird)
