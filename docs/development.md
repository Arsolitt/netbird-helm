# Development and releases

> Repository layout, the fixture contract, the local command set and the CI jobs behind this chart, and how a release tag becomes a published release.

## Table of Contents

- [Repository layout](#repository-layout)
- [Fixture categories](#fixture-categories)
- [Local validation](#local-validation)
- [The CI jobs](#the-ci-jobs)
- [The runtime check](#the-runtime-check)
- [Releasing](#releasing)
- [Adding or changing a value](#adding-or-changing-a-value)
- [Working in this repo](#working-in-this-repo)

---

## Repository layout

This is a single-chart repository: `charts/netbird` is the only chart, and `.github/workflows/ci.yaml` the only pipeline.

```text
netbird-helm/
├── .github/
│   ├── workflows/ci.yaml          # the only pipeline: jobs lint, schema, runtime, release-tag, release
│   ├── CODEOWNERS                 # `* @Arsolitt`
│   ├── dependabot.yml             # weekly, grouped GitHub Actions updates
│   └── PULL_REQUEST_TEMPLATE.md   # what changed / how it was verified / checklist
├── charts/netbird/                # the chart
│   ├── Chart.yaml                 # name netbird, version 3.5.0, appVersion 0.80.0
│   ├── values.yaml                # defaults
│   ├── values.schema.json         # applied by every helm command
│   ├── README.md                  # canonical value reference; ships inside the packaged chart
│   ├── .helmignore                # excludes ci/ - fixtures never ship
│   ├── ci/                        # fixtures: scenarios, invalid, invalid-render
│   ├── examples/                  # complete example configurations
│   └── templates/
│       ├── _helpers.tpl           # named templates (labels, selector labels, fullname, ...)
│       ├── 00-validations.yaml    # fail-fast cross-value checks
│       ├── server-*.yaml          # unified server mode
│       ├── management-*.yaml      # microservice mode
│       ├── signal-*.yaml          # microservice mode
│       ├── relay-*.yaml           # microservice mode, one Deployment/Service pair per `relay.instances` entry
│       ├── dashboard-*.yaml
│       └── service-monitor.yaml   # Prometheus Operator ServiceMonitor
├── docs/                          # this documentation tree
├── hack/
│   ├── runtime-check.sh           # the runtime gate - the `runtime` job just calls it
│   ├── selector-check.py          # the selector gate - the `lint` job calls it per render
│   ├── release.sh                 # cuts a release tag; `--check` is what the `release-tag` job runs
│   └── release-notes.sh           # prints a CHANGELOG section as the GitHub release body
├── AGENTS.md                      # chart conventions for coding agents
├── CHANGELOG.md                   # Keep a Changelog; a released version's section is its release body
├── LICENSE                        # GPL-3.0
└── README.md                      # landing page, install instructions, the release flow
```

There is no test framework; the gates are `helm lint`/`helm template`, `kubeconform`, the schema and fixture folders, and the runtime script. Local build artifacts are gitignored: `tmp`, `.tmp`, `*.tgz`, `.cr-release-packages/`, `.cr-index/`.

## Fixture categories

Three folders, one meaning each. The folder is the contract: a fixture in the wrong folder makes the job that owns it fail, not pass.

| Folder | What the fixture must do | Owning job |
|---|---|---|
| `charts/netbird/ci/*-values.yaml` | render `helm template`, keep the selectors check green, **and** start its image in the runtime check | `lint`, `schema`, `runtime` |
| `charts/netbird/ci/invalid/*.yaml` | be rejected by `values.schema.json` | `schema` |
| `charts/netbird/ci/invalid-render/*.yaml` | be rejected by a template `fail`, naming the value in its `# expect-error:` line | `schema` |

### Scenarios - `charts/netbird/ci/*-values.yaml`

Partial overrides of `values.yaml` (never a copy of the defaults), one per supported topology or
value axis worth permanent coverage - for example unified `server` mode, microservice mode with
relay instances, the dashboard, ingress and ServiceMonitor configurations, and the shape overrides
(string ports, numeric quantities) that existed before the schema did. Every scenario must render,
and the `runtime` job starts the images that scenario renders, so a scenario exists only if its
images can start in CI.

A scenario that cannot start outside a cluster - external databases, certificate files that are not
in the image - opts out of the runtime gate with a `# runtime-skip: <reason>` line in its first
comment block. The `lint` and `schema` jobs still render it; the `runtime` job skips every container
of that fixture, prints the reason as a notice, and still fails unless every image kind was
exercised by some other scenario.

### Schema-rejected fixtures - `charts/netbird/ci/invalid/`

One offending key each, with a comment naming the failure it represents. Add one whenever a new
schema rule is introduced.

### Template-rejected fixtures - `charts/netbird/ci/invalid-render/`

Not every impossible value is a schema question. Rules that span two values belong to a template,
and every fixture in this folder declares, in its first comment lines, the substring the refusal has
to contain:

```yaml
# expect-error: Cannot enable both server
```

The `# expect-error:` line is read with `sed -n 's/^# expect-error: //p'`, so it must start at
column 1, and the job matches it with `grep -qF` against the combined render output - renaming a
value inside a template's `fail` message therefore breaks the fixture loudly instead of silently.
The chart's current cross-value rules live in `charts/netbird/templates/00-validations.yaml`: the
deployment-mode exclusivity (`server` versus `management`/`signal`), and the relay instance list
(`relay.instances` must be a list, every entry needs a `name`, names must be unique, `stun.enabled`
needs `stun.ports`).

Every check fails closed:

| Situation | Job result |
|---|---|
| A fixture in `ci/invalid-render/` carries no `# expect-error:` line | `::error file=<fixture>::<fixture> has no '# expect-error: <substring>' line naming the value the render must report` |
| Such a fixture renders instead of failing | `::error file=<fixture>::<fixture> rendered, but a template has to refuse it (<expected>)` |
| Such a fixture is refused by the schema instead of by a template | `::error file=<fixture>::<fixture> was rejected by values.schema.json, not by the template that owns the rule (<expected>)` |
| Such a fixture is refused, but the message does not contain the declared substring | `::error file=<fixture>::<fixture> was refused without naming '<expected>'` |
| A fixture in `ci/invalid/` renders successfully | `::error file=<fixture>::<fixture> was accepted, but it must be rejected by charts/netbird/values.schema.json` |
| A fixture in `ci/invalid/` fails for a reason that does not mention the schema | `::error file=<fixture>::<fixture> failed for an unexpected reason (not schema validation)` |
| All fixtures are deleted, renamed or moved out of `ci/invalid/` or `ci/invalid-render/` | `::error::no fixtures under charts/netbird/ci/invalid/ - this check would pass without validating anything` |

## Local validation

Run these from the repository root. Every one of them is also what CI runs.

| Command | Proves |
|---|---|
| `helm lint --strict charts/netbird` | template shape and value validation against `values.schema.json` for the defaults |
| the scenario render loop | every supported scenario still renders |
| `helm template … \| kubeconform -strict -summary …` | rendered manifests are valid against a Kubernetes schema |
| the `ci/invalid/` loop | the schema still refuses these shapes |
| the `ci/invalid-render/` loop | the templates still refuse these combinations |
| the selector assertion (CI step `Selectors are immutable and select their own pods`) | no selector carries a label that moves with the chart version, and every workload's pod template carries what its selector asks for - on the defaults and on every scenario |
| `hack/runtime-check.sh charts/netbird` | the real image starts per fixture and its rendered readiness path answers - the only gate that sees a config or probe the shape-only jobs cannot |

```console
$ helm lint --strict charts/netbird
$ for f in charts/netbird/ci/*-values.yaml; do helm template ci charts/netbird -f "$f" > /dev/null || exit 1; done
$ helm template ci charts/netbird > /tmp/render.yaml
$ kubeconform -strict -summary -kubernetes-version 1.31.0 \
    -schema-location default \
    -schema-location '/tmp/crds-catalog/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    /tmp/render.yaml
$ for f in charts/netbird/ci/invalid/*.yaml; do helm template ci charts/netbird -f "$f" > /dev/null && echo "unexpectedly accepted: $f"; done
$ for f in charts/netbird/ci/invalid-render/*.yaml; do helm template ci charts/netbird -f "$f" > /dev/null && echo "unexpectedly accepted: $f"; done
$ helm template ci charts/netbird > /tmp/render.yaml && python3 hack/selector-check.py /tmp/render.yaml
$ hack/runtime-check.sh charts/netbird
```

Read the output of the two negative loops: they only `echo "unexpectedly accepted: <file>"`, they do
not exit non-zero. CI turns the same conditions into a red job. Failures look like this:

| Command | What a failure looks like |
|---|---|
| `helm lint --strict` | non-zero exit with the offending template path or schema violation |
| scenario render loop | `helm template` fails and the loop exits 1 |
| kubeconform | non-zero exit with per-resource errors; CI runs it on both pinned versions (`1.31.0` and `1.37.0`) and additionally asserts the summary reports exactly as many resources as the render has `kind:` lines and that it ends with `Skipped: 0` |
| the selector assertion | `::error::a selector breaks an upgrade - <fixture>: <object> selects on helm.sh/chart: …`, and the step exits 1; `hack/selector-check.py` exits 1 on the first render with a finding, and 2 when the render has no workload or no Service |
| runtime check | the failing fixture, the failing assertion and the container's log tail; the script exits non-zero on the first failing fixture |

> **Warning:** `helm lint --strict` can exit 0 on values that `helm install`/`upgrade` refuse. The chart's cross-value guards surface as `level=INFO msg="funcMap fail"` during lint while the exit code stays 0, so verify those changes with `helm template` or `helm install --dry-run`, not with lint alone.

> **Note:** CI pins Helm to the version in the workflow `env:` block (`4.3.0`); a local Helm can be older, and lint output and template error text can differ between versions. The `env:` block is the reference for what the gate actually runs.

> **Warning:** kubeconform ships no schema for `monitoring.coreos.com`, and `-strict` turns a missing schema into a failure, so a scenario that enables `metrics.serviceMonitor` needs the same extra schema the workflow fetches - `servicemonitor_v1.json` from the pinned CRDs-catalog commit, passed as a second `-schema-location` next to `default`. The one-liner above renders the defaults, which carry no ServiceMonitor.

Other useful commands from the same list:

```console
$ helm template release-name charts/netbird --include-crds > output.yaml
$ helm dep up charts/netbird
$ helm install test-release charts/netbird --dry-run
$ helm package charts/netbird
```

`helm dep up` is a no-op today (`Chart.yaml` declares no dependencies), `output` and `*.tgz` are
gitignored, and `helm package` is how you confirm the `ci/` exclusion: the resulting
`netbird-<version>.tgz` contains `.helmignore`, `Chart.yaml`, `README.md`, `values.yaml`,
`values.schema.json` and `templates/*` only.

## The CI jobs

`.github/workflows/ci.yaml` is the only pipeline. It runs on every `pull_request`, on `push` to
`main` and on a push of a `v<version>` tag; job ids double as status-check contexts, and the first
three are meant to be required on pull requests.

| Job | Name | Runs | Protects against |
|---|---|---|---|
| `lint` | Lint and validate manifests | `helm lint --strict` for the defaults and every scenario; `helm template` + `kubeconform -strict` for the **default values** and every scenario, on each version in `KUBERNETES_VERSIONS` (`1.31.0 1.37.0`), asserting that the summary reports exactly the rendered resource count and `Skipped: 0`; the `ServiceMonitor` schema comes from a pinned CRDs-catalog commit because kubeconform has no `monitoring.coreos.com` schema and `-strict` fails on a missing one; `Selectors are immutable and select their own pods` (`hack/selector-check.py` on the defaults and every scenario: no `spec.selector.matchLabels` and no Service `selector` may carry `helm.sh/chart`, `app.kubernetes.io/version` or `app.kubernetes.io/managed-by`, and every workload's own pod template has to carry the pairs its selector asks for) | a scenario that stops rendering, a manifest that violates the Kubernetes or ServiceMonitor schemas, and a selector that moves with the chart version - which renders fine and is only discovered by the *next* chart release |
| `schema` | Value schema guardrails | every `ci/invalid/*.yaml` must be refused by the schema; every `ci/invalid-render/*.yaml` must be refused by a template and name its value; every scenario must still render | a weakened `values.schema.json` or a dropped template guard |
| `runtime` | Runtime smoke test against the real image | checkout, the pinned Helm, then `hack/runtime-check.sh "$CHART_DIR"` (`timeout-minutes: 25`) | a config value of the wrong type and a readiness path that answers non-200 - neither is visible to the shape-only jobs |
| `release-tag` | Resolve the release tag | a `v<version>` tag push only; `hack/release.sh --check "$GITHUB_REF_NAME"` resolves `version`, `channel`, `section` and `tag` (the same script that cuts the tag, so the rules cannot drift), then the job refuses a tag that is not an ancestor of `origin/main` | a version that is neither `<major>.<minor>.<patch>` nor `<major>.<minor>.<patch>-rc.<n>`, a missing `## [<version>]` CHANGELOG section, and a tag not cut from `main` - each fails in seconds, before the `runtime` gate |
| `release` | Release chart | a `v<version>` tag push only, `needs: [release-tag, lint, schema, runtime]`, `concurrency: chart-release`; packages the tagged tree with `helm package --version` (stamping the tag's version, then reading it back out of the `.tgz`), creates the GitHub release with `gh release create` (the body is `hack/release-notes.sh <version> [<section-version>]`, the package is the uploaded asset, and the track is the flag: `--prerelease --latest=false` for a candidate, `--latest` for a stable release; a re-run edits the release it finds instead), then runs `cr index` with `--release-name-template 'v{{ .Version }}'` (that template is the tag it looks the release up by, and its default would be `<chart name>-<version>`) `--push` to rewrite `index.yaml` on `gh-pages` (the pinned `cr` comes from `chart-releaser-action@v1.7.0` with `install_only: true` - the action's own release path packages "charts changed since the previous tag" and dies on an unbound variable when packaging is skipped), and finally commits the released `version` to `main` as `chore(release): record <tag> [skip ci]` | a package that does not carry the released version, a candidate that exists unflagged (a pre-release has to be born one, or a failed run leaves a stable-looking release behind), a release body that stayed the chart description, and a release recorded nowhere on the branch |

Tool pins live in the workflow `env:` block - one pin per tool, no `@latest` anywhere; Dependabot
only bumps the actions.

| Pin | Value |
|---|---|
| `HELM_VERSION` | `4.3.0` |
| `KUBECONFORM_VERSION` | `v0.8.0` |
| `KUBECONFORM_SHA256` | `9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883` |
| `CRDS_CATALOG_SHA` | `b8e5c58dd9a34bc48c4d28718d7321bd8df8c22a` |
| `SERVICEMONITOR_SCHEMA_SHA256` | `8978f86e2a7cb281a9ca7bc30d857e0553666658dfe062078c51e99d3f20cd14` |
| `CHART_RELEASER_VERSION` | `v1.8.1` |
| `KUBERNETES_VERSIONS` | `1.31.0 1.37.0` |
| `CHART_DIR` | `charts/netbird` |
| action pins | `actions/checkout@v7`, `azure/setup-helm@v5`, `helm/chart-releaser-action@v1.7.0` |

Bumping `KUBECONFORM_VERSION` or `CRDS_CATALOG_SHA` without updating the matching checksum fails the
job at `sha256sum -c`; those pins travel together.

The `release` job is gated four ways: it runs only on a tag push
(`if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')`),
`needs: [release-tag, lint, schema, runtime]`, `permissions: contents: write` (the workflow default
is `contents: read`), and `concurrency: chart-release`, which serialises releases across refs - two
tags pushed close together would otherwise race on the same branch. The workflow keeps its own group
(`${{ github.workflow }}-${{ github.ref }}`, cancelling in progress only for pull requests).

> **Note:** There is deliberately no `paths:` filter on `pull_request`. A job skipped by a path filter never reports a status, so requiring it would block every merge that does not touch those paths - which is also why a docs-only pull request still runs the quality jobs.

## The runtime check

`hack/runtime-check.sh` is the only gate that starts the real images. It renders every
`charts/netbird/ci/*-values.yaml` with the pinned Helm (the bare chart defaults are not a runtime
scenario - they carry placeholder values the upstream process refuses to start on, and stay covered
by the `lint`/`kubeconform` jobs), reads the images, environment,
config, probes and readiness paths out of that render rather than hardcoding them, starts each
container against its rendered configuration, and asserts that the process keeps running and that
its readiness path answers - then removes the container before moving on. It needs docker, helm and
python3 with PyYAML.

The script skips, with a printed notice and never silently: a container whose rendered env needs an
unresolvable `valueFrom`/`envFrom` source, a relay container whose literal env lacks
`NB_EXPOSED_ADDRESS` or `NB_AUTH_SECRET` (the upstream relay exits without both), and every
container of a fixture carrying `# runtime-skip: <reason>`. The run fails unless all five image
kinds (`netbird-server`, `management`, `signal`, `relay`, `dashboard`) were started by some fixture.

```console
$ hack/runtime-check.sh charts/netbird
```

Usage is `hack/runtime-check.sh <chart-dir>` - the workflow passes `$CHART_DIR` (`charts/netbird`),
so run it from the repository root with the same argument to pre-flight exactly what CI runs. It
exits non-zero on the first failing fixture, naming the fixture, the failed assertion and the
container's log tail.

> **Note:** The rule that matters when you change a manifest: the script reads images, env names, paths and probes out of the render and hardcodes none of them. If the script needs to know something the manifests do not say, that is a bug in the manifests.

## Releasing

A release is a tag push. Both tracks are cut from `main`, and nothing in the tree is bumped by hand:
the tag carries the version, the release job stamps it into the package, and the branch records it
afterwards.

| | stable track | release candidate track |
|---|---|---|
| version shape | `<major>.<minor>.<patch>` | `<major>.<minor>.<patch>-rc.<n>` |
| tag | `v3.5.0` | `v3.6.0-rc.1` |
| CHANGELOG section | `## [3.5.0]` | `## [3.6.0]` - the version it is a candidate of |
| GitHub release | normal, "Latest" | `--prerelease`, never "Latest" |

1. Write the section the release body comes from: `## [<version>]` in `CHANGELOG.md`, once per
   version and before the first tag of it. A candidate reuses the section of the version it is a
   candidate of, so `3.6.0-rc.1` publishes `## [3.6.0]`; the heading date is the day the section was
   opened.
2. Cut the tag with `hack/release.sh <version>` - the only thing that creates one. It refuses a
   version that is neither shape, a missing CHANGELOG section (it runs `hack/release-notes.sh` as
   the check), a dirty working tree, a `HEAD` that is not the tip of `origin/main`, and a tag that
   already exists locally or on `origin`. The tag names the commit below the release job's own
   record commits, never the `chore(release): record <tag> [skip ci]` tip: a skip token makes GitHub
   create no run at all for a push, and a tag push is a push, so a tag on that tip would release
   nothing - 0 runs for the tag ref, no failure, no release. The script prints
   `stepping past <sha> (<subject>)` for each record commit it steps over. Legacy
   `chore(release): record netbird-<version>` subjects are stepped over the same way.
3. Pushing the tag starts the run. `release-tag` resolves it through the same script and refuses a
   tag that is not an ancestor of `origin/main`; `lint`, `schema` and `runtime` gate the release.
4. The `release` job packages the tagged tree with `helm package --version` - the tag carries the
   version, and the tree still records the *previous* release because the recording commit lands
   only afterwards - then reads the package back to prove its `Chart.yaml` carries that version, and
   creates the GitHub release with `gh release create`: the body is the `## [<version>]` section
   from `hack/release-notes.sh "$VERSION" "$SECTION"`, the uploaded asset is the package this job
   built, and the track decides the flag - `--prerelease --latest=false` for a candidate, `--latest`
   for a stable release. The release has to be *born* with that flag: `cr` cannot create a
   pre-release, and a candidate that exists unflagged, even for the seconds between two steps, is
   one consumers see as stable.
5. `cr index --release-name-template 'v{{ .Version }}' --push` rewrites `index.yaml` on the
   `gh-pages` branch: it looks the release up by that tag, reads it and its asset back out of GitHub
   and writes the entry that points at `releases/download/<tag>/<package>`. `concurrency: chart-release`
   serialises releases, and `main` never moves backwards - a release cut from an older commit
   publishes and leaves the branch alone.
6. The last step commits the released version to `main` as
   `chore(release): record <tag> [skip ci]`, writing `version` into `charts/netbird/Chart.yaml`. A
   push made with `GITHUB_TOKEN` starts no run by itself, and `[skip ci]` keeps the commit out of a
   pipeline if that ever changes - and it is why the tip a maintainer finds after a release is
   exactly the commit a tag must not name (step 2).
7. Consumers pick the version up with `helm repo update`. A candidate is opt-in: an unqualified
   `helm install` keeps resolving the newest stable, and the candidate needs
   `helm search repo netbird/netbird --versions --devel` / `helm install … --version 3.6.0-rc.1`.

The release body is not the releaser's: `chart-releaser` carries no notes input (`cr upload` reads a
notes file only from inside the packaged chart) and cannot create a pre-release at all, so the
release itself is created with `gh release create` from what `hack/release-notes.sh` prints, and
`cr` is left with the index. The version is never read out of the checkout either - `release-tag`
resolves it from the tag, and the packaging step stamps it into the package.

`hack/release-notes.sh <version> [<section-version>]` prints the `## [<section-version>]` section of
`CHANGELOG.md` (the second argument defaults to the first), from the heading up to (excluding) the
next `## ` heading, plus a best-effort
`**Full Changelog**: https://github.com/<repo>/compare/<previous-tag>...<tag>` line when the
repository, the `v<version>` tag and a previous tag are all resolvable. The previous tag is
track-aware: a candidate compares against whatever preceded it, a stable release against the
previous *stable* one, so a stable body is the whole section rather than what changed since the last
candidate. The earlier `netbird-*` tags count too, so the first release under the `v` prefix
compares against the newest tag of its own track there - `v3.5.0` against `netbird-3.4.0`.

| Invocation | Result |
|---|---|
| `hack/release-notes.sh 3.5.0` | exit 0, the section plus the compare link on stdout - one argument means the section version is the released version |
| `hack/release-notes.sh 3.6.0-rc.1 3.6.0` | exit 0, the `## [3.6.0]` section - the form a candidate is published with, once that section exists |
| `hack/release-notes.sh 9.9.9` | exit 1, nothing on stdout, `no '## [9.9.9]' section in <...>/CHANGELOG.md: add it before releasing 9.9.9, the GitHub release body is taken from it` |
| `hack/release-notes.sh 3.6.0-rc.1 9.9.9` | exit 1, nothing on stdout, the same message naming `## [9.9.9]` as the missing section and `3.6.0-rc.1` as the version being released |
| `hack/release-notes.sh` (no argument) | exit 2, `usage: hack/release-notes.sh <version> [<section-version>]   (e.g. 3.5.0, or 3.6.0-rc.1 3.6.0 for a candidate)` |
| `CHANGELOG_FILE=<path> hack/release-notes.sh <version>` | reads that file instead of the repository changelog (the documented test hook); a missing file exits 1 with `no changelog file <path>: it holds the release body for <version>` |

The heading match is a literal prefix and requires a space or the end of the line after the closing
bracket, so looking for `3.5.0` cannot pick up a `## [3.5.0-rc1]` heading above it. A heading written
as `## [3.5.0]-something` matches nothing, so `hack/release.sh` refuses to create the tag and
`release-tag` refuses it again in CI - a version whose section is missing cannot be published at all.

| Failure mode | What happens |
|---|---|
| No `## [<version>]` section for the tagged version | `hack/release.sh` refuses to cut the tag, and `release-tag` refuses the tag again in CI: the run fails before the gates and before anything is published - not after the release exists |
| A version of any other shape (`9.9`, `9.9.9-rc`, `9.9.9-rc.1.2`, `foo-9.9.9`) | `hack/release.sh` exits 2 without creating a tag; pushed anyway, the same check fails the run in `release-tag` |
| A tag that is not an ancestor of `origin/main` | `release-tag` fails the run in seconds; nothing is published |
| A tag cut at a commit that carries a workflow-skip token | GitHub creates no run for the tag ref at all - 0 runs, no failure, no release - so the tag has to be deleted and re-cut. `hack/release.sh` steps past the release job's own record commits (printing `stepping past <sha> (<subject>)`) and names the commit below them; a skip token that is there for any other reason is refused instead, with `<tag> would name <sha> (<subject>), which carries a workflow-skip token: GitHub creates no run for it, so the release would never happen`, since stepping over that commit would leave its content out of the release |
| A merge that only touches docs, CI or even the chart | nothing is published - a release needs a tag push, and there was none |
| A release candidate | supported: it publishes a GitHub pre-release (never "Latest") with the section of the version it is a candidate of, and consumers opt in with `--devel` / `--version` |
| A pin and its checksum updated separately | the job fails at `sha256sum -c` before validating anything |

> **Tip:** To see what is actually published, read `origin/gh-pages` (or the chart repository URL) rather than a local `gh-pages` branch - a checkout's local branch can lag the published `index.yaml`.

> **Note:** The recovery depends on whether anything was published. While the release was refused - a version of the wrong shape, a missing section, a tag that is not on `main`, a tag cut at a skip-token commit - nothing exists on the repository yet, so the tag can be deleted and re-pushed. Once the release exists the tag must not move: recover with `gh run rerun` (the release is edited rather than recreated, its asset is re-uploaded, and the index and the version record are retried), or, when the workflow itself is the defect, re-run the affected steps by hand.

## Adding or changing a value

Adding a value means touching three places:

| Place | What changes |
|---|---|
| `charts/netbird/values.yaml` | the value itself, with a comment (`## @param`) and its default |
| `charts/netbird/values.schema.json` | the shape rule that keeps impossible values out |
| [`charts/netbird/README.md`](../charts/netbird/README.md) | the value tables (this file ships inside the packaged chart, so it is the reader's reference) |

Then decide the fixture:

| If the change | Put it |
|---|---|
| is a combination of values worth permanent coverage | a scenario in `charts/netbird/ci/<name>-values.yaml` |
| has a shape that must be rejected | a fixture in `charts/netbird/ci/invalid/` |
| is a rule that spans two values and belongs to a template | a fixture in `charts/netbird/ci/invalid-render/` with the `# expect-error:` line |

The full procedure for a configuration key is: add it to `values.yaml` with a comment and default,
reference it in a template, cover it in `values.schema.json`, update the chart README, then test with
`helm template` (or add a scenario when the combination deserves permanent coverage).

Two packaging rules apply to everything under `ci/`:

- `charts/netbird/.helmignore` excludes `ci/`, so scenarios and negative fixtures never ship in the
  packaged chart. `helm package charts/netbird` is the check.
- If a new value renders a kind that no earlier render produced, the `lint` job fails until that
  kind's schema is in the pinned set - a rendered resource kubeconform cannot find a schema for is a
  failure (`kubeconform skipped resources, so a kind has no schema (add it to the pinned set)`),
  never a silent pass. The `ServiceMonitor` kind is handled that way already.

## Working in this repo

[`AGENTS.md`](../AGENTS.md) carries the chart conventions a change must follow; the essentials:

| Area | Rule |
|---|---|
| Whitespace control | `{{-` trims before, `-}}` trims after; wrap optional resources in `{{- if .Values.x.enabled -}}` |
| Indentation | 2 spaces throughout, `nindent` for nested blocks |
| Naming | Templates `netbird.<component>.<purpose>`; resource files kebab-case with a component prefix; `00-` prefix for the fail-fast validation file |
| Labels | Every resource carries `{{- include "netbird.<component>.labels" . \| nindent 4 }}`; selectors use only the `*.selectorLabels` helpers |
| Security contexts | Pod- and container-level security contexts with `runAsNonRoot`, dropped capabilities and a `RuntimeDefault` seccomp profile on every workload |
| `values.yaml` style | `## @section` / `## @param` annotations, grouped by component (global, server, dashboard, management, signal, relay, metrics) |
| Env vars | three patterns: plain `env` map, `envFromSecret` shorthand (`VAR: secretName/secretKey`), and raw `envRaw` entries |
| Pins | Nothing uses `@latest`: the workflow `env:` block pins Helm, kubeconform (+ sha256), chart-releaser, the Kubernetes versions and the CRDs-catalog commit; Dependabot bumps the GitHub Actions only |
| Version and tags | the tag carries the version: `hack/release.sh <version>` creates it, and the release job records it in `charts/netbird/Chart.yaml` on `main` afterwards; `appVersion` is updated in a pull request when the NetBird version changes |
| Documentation | the repository's prose is English - `values.yaml` comments, `charts/netbird/README.md`, `CHANGELOG.md`, `ci/` fixture header comments - and every fixture header explains why the fixture exists |

The pull request template asks for what changed, how it was verified, and a checklist: lint passes,
every scenario renders, `hack/runtime-check.sh` passes, new or changed values are covered by
`values.schema.json` and the chart README tables, nothing under `ci/invalid/` became acceptable to
the schema, and `CHANGELOG.md` carries the section for the version the change ships in. A release is cut with
`hack/release.sh <version>` - nothing publishes on merge. `.github/CODEOWNERS` assigns every path to
one owner, and Dependabot opens weekly grouped action updates rather than touching the manual tool
pins.
