# Changelog

All notable changes to the netbird Helm chart. The section for a released
version is published as that GitHub release's body by the `release` job in
`.github/workflows/ci.yaml`.

Versions come from the git tag, not from a hand-edited `Chart.yaml`: the tag is
`v<version>`, where `<version>` is either a stable release (`3.5.0`) or a
release candidate (`3.6.0-rc.1`); earlier releases used `netbird-*` tags. The
section published is `## [<version>]` - a candidate publishes the section of the
version it is a candidate of, so `3.6.0-rc.1` publishes `## [3.6.0]`. Write the
section before cutting the first tag of the version; its heading date is the day
the section was opened.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [3.5.0] - 2026-10-05

### Added

- **The chart's releases are tag-driven now.** `hack/release.sh <version>` is the only thing that
  creates a release: it cuts a `v<version>` tag (`v3.5.0`, or `v3.6.0-rc.1` for a release candidate),
  and pushing it runs the pipeline that packages the chart with that version, publishes the GitHub
  release together with the `gh-pages` chart index entry, and records the version in `Chart.yaml` on
  `main` afterwards. The release body is the `## [<version>]` section of this file, so the notes are
  written here and never generated from commit messages.
- **Quality gates for every change.** The chart now ships a `values.schema.json` that every `helm`
  command applies, a `charts/netbird/ci/` fixture set (rendered scenarios, schema-rejected values and
  template-rejected value combinations), and a runtime smoke test (`hack/runtime-check.sh`) that
  starts the real image per fixture and probes the readiness path. `.github/workflows/ci.yaml` runs
  them as the `lint`, `schema` and `runtime` jobs, and the same gates hold a release tag. See
  [docs/development.md](./docs/development.md).
- **`relay.instances[].strategy`**, a full Deployment strategy object per relay instance, defaulting
  to `Recreate` when absent - a relay pod that binds host ports or node-local resources is replaced
  before its successor starts.
- **`signal.strategy`**, mirroring `management.strategy`: default `RollingUpdate` with
  `maxSurge: 25%` / `maxUnavailable: 25%`.
- **Service `annotations` and `externalIPs`** for `management.service` (HTTP), `management.serviceGrpc`,
  `signal.service`, `dashboard.service`, `server.service`, `server.serviceStun`,
  `relay.instances[].service` and `relay.instances[].stun.service` - parity with the upstream chart's
  service parameters; each field is rendered only when it is set.
- **ServiceMonitors for management and signal** when their `metrics.enabled` and
  `metrics.serviceMonitor.enabled` are set, alongside the existing server and per-instance relay
  monitors.
- **NetBird 0.80 combined-config keys** in the `server.config` passthrough, including
  `auth.sessionCookieEncryptionKey`.
- **Image bumps:** the NetBird components (unified `netbird-server`, `management`, `signal`, `relay`)
  to 0.80.0, and the dashboard default tag to `v2.94.0`.

### Fixed

- Relay templates no longer fail to render when an instance omits its optional blocks: `stun`,
  `stun.service` and the probe overrides are treated as optional per instance.
- Render validations now refuse duplicate relay instance names, `stun.enabled` without
  `stun.ports`, and the unified `server` combined with the microservice `signal` - in addition to the
  existing `server` + `management` refusal.
- Unified-server readiness and liveness probes default to a TCP check on the `http` port: the
  previous `httpGet /health:9000` can never return 2xx in unified mode (the healthcheck endpoint
  serves the combined relay healthcheck, which registers no listeners), so the pod never became
  Ready.
- Multi-document relay and ServiceMonitor templates render clean separators under Helm 4
  `helm lint`: a `---` glued to the next document's `apiVersion` made lint fail for any render with
  more than one relay instance or ServiceMonitor.
- With `metrics.enabled`, the configured `metrics.port` now reaches the process as well
  (`NB_METRICS_PORT` for relay and signal, `--metrics-port` for management); previously a custom port
  moved the container port and ServiceMonitor but left the process serving 9090.

### Changed

- **A release is a pushed `v<version>` tag, and merging publishes nothing.** The old
  chart-releaser-on-`main` workflow is gone; `main` is recorded by the release job after the fact.
  Previous releases keep their `netbird-*` tags, and the chart repository index serves them as before.

## [3.4.0] - 2026-09-05

### Added

- `relay.instances[].stun.hostPort` (default `false`): mirror each STUN UDP port as a `hostPort` on
  the relay container, for clusters where LoadBalancer or NodePort UDP handling is undesirable. Pods
  are spread across nodes, one node per replica.

## [3.3.0] - 2026-09-05

### Added

- Service annotations for relay instances: `service.annotations` on the relay's TCP Service and
  `stun.service.annotations` on its STUN Service, e.g. for LoadBalancer IP-pool or lbipam pinning.

## [3.2.0] - 2026-07-03

### Changed

- NetBird bumped to 0.74.1 and the dashboard image to `v2.90.3`.

## [3.1.0] - 2026-06-18

### Changed

- NetBird bumped to 0.72.4 and the dashboard image to `v2.39.0`.

## [3.0.0] - 2026-03-30

### Added

- **Relay multi-instance support:** `relay.instances` is a list, and each entry renders its own
  Deployment, TCP Service, STUN Service, Ingress and ServiceAccount - per instance `name`,
  `replicaCount`, config, resources, probes, pod annotations and more, with document separators
  between the rendered instances.
- Per-instance ServiceMonitor support for relay metrics.
- Render validation for the relay instance list: it must be a list and every entry needs a `name`.

### Changed

- The relay values were restructured around the `relay.instances` list; examples were updated for the
  multi-instance form.

### Fixed

- Nil-safe access to optional per-instance fields, so a minimal instance renders.

## [2.3.2] - 2026-03-16

### Added

- `dashboard.deploymentAnnotations`.

### Fixed

- Dashboard: nginx log and tmp directories are mounted as subPaths and the security context was
  relaxed for nginx compatibility; the dashboard image moved to `v2.34.2`.
- Signal: an explicit `NB_PORT` environment variable, and the Service port corrected from 80 to
  8080.

## [2.3.1] - 2026-03-15

### Changed

- The README and chart documentation warn that unified server mode is unstable and recommend
  microservice mode for production deployments.

## [2.3.0] - 2026-03-15

### Added

- **Microservice mode:** separate `management`, `signal` and `relay` Deployments with their Services,
  Ingresses and ServiceAccounts, next to the unified `server` mode; the two modes are mutually
  exclusive, enforced by a render validation.
- **Dashboard:** the web UI Deployment, Service, Ingress and ServiceAccount.
- **Relay STUN support:** a STUN Service per relay, alongside the relay's main Service.
- Persistence for the management and server components, extra manifests (`extraManifests`) and a
  Prometheus Operator ServiceMonitor.
- Security hardening for every component: non-root pod and container security contexts, tmpfs volumes
  and unprivileged container ports.
- Examples reorganized by ingress controller (nginx, traefik) and identity provider (Auth0, Google,
  Okta, Authentik), plus a minimal example.

### Changed

- NetBird bumped to 0.66.4 with the unified server architecture.
