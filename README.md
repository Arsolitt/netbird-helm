# NetBird Helm Chart

Helm chart for deploying [NetBird](https://github.com/netbirdio/netbird) - a WireGuard-based mesh VPN platform.

This chart supports both unified server mode and microservice mode for flexible deployments.

> **Note:** This chart is based on [totmicro/helms](https://github.com/totmicro/helms).

> **Note:** Unified server mode requires a complete `server.config` - the chart defaults are placeholders and the `netbird-server` process exits at startup until `exposedAddress`, `authSecret`, `auth.issuer` and a base64 `store.encryptionKey` are set. `charts/netbird/ci/server-minimal-values.yaml` is a minimal working set, and the runtime CI gate starts the real image on every fixture.

## Features

- **Unified Server Mode** - Single deployment with management, signal, relay and STUN (requires a complete `server.config`)
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
  instances:
    - name: default

dashboard:
  enabled: true
```

See [examples](charts/netbird/examples/) for complete configurations.

## Examples

See [charts/netbird/examples/](charts/netbird/examples/) for complete deployment examples:

- **nginx-ingress/** - Examples with Auth0, Google, Okta, Authentik (microservice mode)
- **traefik-ingress/** - Authentik example with Traefik (microservice mode)

## Releasing New Chart Versions

Releases are tag-driven: a release exists only because a `v<version>` tag was pushed, and a merge to
`main` publishes nothing. Write the `## [<version>]` section in [CHANGELOG.md](CHANGELOG.md) first -
it becomes the GitHub release body - then cut the tag:

```console
$ hack/release.sh 3.5.0            # stable; a candidate is 3.6.0-rc.1
```

`hack/release.sh` refuses anything but `<major>.<minor>.<patch>` or `<major>.<minor>.<patch>-rc.<n>`,
a missing CHANGELOG section, a dirty tree, a `HEAD` that is not the tip of `origin/main`, and an
existing tag. Pushing the tag runs the pipeline in
[.github/workflows/ci.yaml](./.github/workflows/ci.yaml): the `lint`, `schema` and `runtime` gates
run first, then the chart is packaged with the tag's version, the GitHub release and its `gh-pages`
index entry are published, and the released version is recorded in `Chart.yaml` on `main`
afterwards. A candidate is published as a GitHub pre-release, never as "Latest". Releases cut before
this pipeline used `netbird-*` tags; they keep working through the chart repository index.

Consumers pick the new version up with `helm repo update`. See
[docs/development.md](docs/development.md) for what each job checks and how to recover a failed
release.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Credits

Based on [totmicro/helms](https://github.com/totmicro/helms).

## Additional Resources

- [NetBird Documentation](https://docs.netbird.io/)
- [NetBird GitHub](https://github.com/netbirdio/netbird)
