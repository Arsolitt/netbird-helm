#!/usr/bin/env bash
#
# Start every container each ci/*-values.yaml scenario renders - exactly the
# way its manifest describes it - and probe the readiness surface that same
# manifest declares. This is what the `runtime` job in .github/workflows/ci.yaml
# runs; the job is a one-liner so a contributor can pre-flight the gate locally.
#
# The chart's bare defaults are deliberately not a scenario: they are
# placeholders (exposedAddress/authSecret/issuer empty) that upstream
# netbird-server refuses to start on, and the lint/render gates cover them; the
# fixtures are the deployable configurations and every one of the five images
# has to be started by at least one of them.
#
# The other gates only prove the manifests have the right *shape*: `helm lint`,
# `kubeconform` and values.schema.json never start a process, and a config value
# of the wrong type, an unreachable address, a missing writable path or a
# readiness path that cannot answer 2xx in the chart's own configuration all
# render perfectly green. The containers are driven by what the render *says*,
# so this script hardcodes no env name, no path and no probe:
#
#   1. `helm template` the scenario and parse the manifests (python3 + PyYAML);
#   2. for every Deployment whose container image is one of the five NetBird
#      images, read the container's image, command, args, ports, env, probes and
#      volume mounts, and the ConfigMaps those mounts project;
#   3. for the unified server, substitute the ConfigMap's config.yaml.tmpl the
#      way the chart's envsubst init container does (literal env values only,
#      ${VAR} placeholders left unresolved become empty strings) and mount the
#      result on the path the container's `--config` names;
#   4. start that image with `docker run -d`: the rendered env (literal values),
#      the rendered ConfigMaps mounted read-only, a container-local tmpfs for
#      every emptyDir/PVC the manifest mounts read-write (a bind mount the
#      container writes into is not removable on a Linux runner afterwards) and
#      only the probed port published on 127.0.0.1;
#   5. poll the rendered readiness probe - httpGet path/port (named ports
#      resolved through the container's own ports list), tcpSocket, or a TCP
#      connect to the first container port when the manifest declares none;
#   6. a container that exits while polling fails immediately with its own
#      `docker logs`: that is how a config value of the wrong type, an
#      unreachable dependency or a missing file surfaces.
#
# Containers whose env references a Secret/ConfigMap (`valueFrom`, `envFrom`) or
# whose volumes come from a Secret cannot be driven from a docker fixture, so
# they are skipped with a notice - but the run fails when any of the five image
# kinds was never exercised, so a fixture rename cannot turn the gate into a
# no-op.
#
# usage: hack/runtime-check.sh [chart-dir]      (default: charts/netbird)
#        RUNTIME_CHECK_TIMEOUT=<seconds>        (ready budget per container, default 180)
#
# Scenarios are <chart-dir>/ci/*-values.yaml, one docker run per NetBird
# container they render. Needs a docker daemon, helm, curl and python3 with
# pyyaml. Exits non-zero on the first failing container; every container this
# starts is removed again on success, on failure and on interrupt.
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: hack/runtime-check.sh [chart-dir]" >&2
  exit 2
fi
chart_dir="${1:-charts/netbird}"

# `::group::`/`::endgroup::` collapse the per-scenario output in the Actions log
# and are pure noise in a terminal; `::error::` stays, it is a single line.
group() {
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::group::$1"
  fi
}
endgroup() {
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::endgroup::"
  fi
}

# A failing container aborts the run: it prints the scenario, the container, the
# assertion that failed and the container's own stderr, which is where a config
# value of the wrong type or a failed bind shows up.
scenario=""
target=""
container=""
kinds_seen=""
cleanup() {
  if [ -n "$container" ]; then
    docker rm -f "$container" >/dev/null 2>&1 || true
  fi
  if [ -n "$kinds_seen" ]; then
    rm -f "$kinds_seen" 2>/dev/null || true
  fi
}
trap cleanup EXIT

fail() {
  echo "::error::$scenario: $1"
  echo "FAIL $scenario${target:+ $target} -> $1"
  if [ -n "$container" ] && docker inspect "$container" >/dev/null 2>&1; then
    echo "--- $container (running: $(docker inspect -f '{{.State.Running}}' "$container"), exit code $(docker inspect -f '{{.State.ExitCode}}' "$container")) ---"
    docker logs "$container" 2>&1 | tail -40 || true
  fi
  exit 1
}

# Without nullglob an unmatched fixture glob is passed to the loop verbatim;
# with it the loop below is skipped and the fixture-count guard fails the run
# instead of checking nothing.
shopt -s nullglob

for tool in docker helm python3 curl; do
  command -v "$tool" >/dev/null 2>&1 \
    || { echo "::error::$tool is not on PATH, but this gate drives the rendered manifests with it"; exit 2; }
done
docker info >/dev/null 2>&1 \
  || { echo "::error::the docker daemon is not reachable"; exit 2; }
python3 -c 'import yaml' >/dev/null 2>&1 \
  || { echo "::error::python3 needs pyyaml to read the rendered manifests"; exit 2; }
[ -d "$chart_dir" ] || { echo "::error::$chart_dir is not a directory"; exit 2; }

# A published port may still be in TIME_WAIT from the previous container; never
# fail a scenario over that.
free_port() {
  python3 - "$1" <<'PY'
import socket, sys
port = int(sys.argv[1])
while True:
    with socket.socket() as sock:
        try:
            sock.bind(("127.0.0.1", port))
        except OSError:
            port += 1
            continue
        print(port)
        break
PY
}

# macOS bash has no usable /dev/tcp, so the TCP probe is a socket connect.
tcp_ok() {
  python3 - "$1" <<'PY'
import socket, sys
with socket.socket() as sock:
    sock.settimeout(2)
    try:
        sock.connect(("127.0.0.1", int(sys.argv[1])))
    except OSError:
        sys.exit(1)
PY
}

# Per-run id for container names and scratch dirs: leftovers from a killed run
# (or a concurrent invocation on a shared host) must not collide with this one.
run_id="${GITHUB_RUN_ID:-$$}"
scratch_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
scratch_root="${scratch_root%/}"
case "$scratch_root/" in
  /*) ;;
  *) echo "::error::refusing to use relative scratch root $scratch_root" >&2; exit 2 ;;
esac

# The scenarios: every fixture. The bare chart defaults are placeholders that
# upstream netbird-server cannot start on (see the header), so they are covered
# by the lint/render gates instead of being started here.
scenarios=()
for values in "$chart_dir"/ci/*-values.yaml; do
  scenarios+=("$values")
done
if [ "${#scenarios[@]}" -eq 0 ]; then
  echo "::error::no fixtures matched $chart_dir/ci/*-values.yaml - this gate would pass without checking anything"
  exit 1
fi

kinds_seen="$scratch_root/netbird-runtime-${run_id}-kinds"
: > "$kinds_seen"

scenario_index=0
port_hint=20000
for scenario in "${scenarios[@]}"; do
  scenario_index=$((scenario_index + 1))
  values="$scenario"
  work="${scratch_root}/netbird-runtime-${run_id}-${scenario_index}"
  rm -rf "$work"
  mkdir -p "$work"

  group "runtime check: $scenario"

  # Everything this scenario's Deployments are made of, read out of the render.
  # The output is one sourceable file per container plus the env files, the
  # projected ConfigMaps and the substituted server config those containers are
  # started with.
  if ! python3 - "$chart_dir" "$values" "$work" <<'PY'
import os, re, subprocess, sys
from shlex import quote
import yaml

chart, values, work = sys.argv[1:4]
label = values or "<chart defaults>"


def die(message):
    sys.exit(f"{label}: {message}")


def fixture_skip_reason(path):
    """`# runtime-skip: <reason>` in a fixture's first comment block.

    Some fixtures exist to exercise a render path (TLS files, an external
    database, a Secret-only env) that no docker run can satisfy; the marker
    skips the whole fixture explicitly instead of failing the gate on it.
    """
    if not path:
        return ""
    try:
        with open(path) as handle:
            for raw in handle:
                stripped = raw.strip()
                if not stripped:
                    continue
                match = re.match(r"^#\s*runtime-skip:\s*(.+?)\s*$", stripped)
                if match:
                    return "fixture marked runtime-skip: " + match.group(1)
                if not stripped.startswith("#"):
                    break
    except OSError:
        pass
    return ""


fixture_skip = fixture_skip_reason(values)

cmd = ["helm", "template", "ci", chart]
if values:
    cmd += ["-f", values]
try:
    manifest = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
except subprocess.CalledProcessError as exc:
    die(f"helm template failed:\n{(exc.stderr or '').strip()}")

docs = [doc for doc in yaml.safe_load_all(manifest) if isinstance(doc, dict)]
configmaps = {d["metadata"]["name"]: d for d in docs if d.get("kind") == "ConfigMap"}

KINDS = {
    "netbirdio/netbird-server": "server",
    "netbirdio/management": "management",
    "netbirdio/signal": "signal",
    "netbirdio/relay": "relay",
    "netbirdio/dashboard": "dashboard",
}


def image_kind(image):
    """The chart image this container runs, or None for an unrelated image."""
    repo = str(image)
    if "@" in repo:
        repo = repo.split("@", 1)[0]
    last = repo.rsplit("/", 1)[-1]
    if ":" in last:
        repo = repo.rsplit(":", 1)[0]
    for candidate, kind in KINDS.items():
        if repo == candidate or repo.endswith("/" + candidate):
            return kind
    return None


def sh_array(name, items):
    """A sourceable bash array assignment."""
    return f"{name}=({' '.join(quote(str(item)) for item in items)})"


def substitute(text, env):
    """envsubst semantics: ${VAR} and $VAR, unknown names become empty."""
    pattern = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)")

    def replace(match):
        return env.get(match.group(1) or match.group(2), "")

    return pattern.sub(replace, text)


def env_pairs(container):
    """Literal env values only; valueFrom/envFrom need a cluster and are named."""
    pairs, unresolved = [], []
    for entry in container.get("env") or []:
        name = str(entry.get("name", ""))
        if "value" in entry:
            value = entry["value"]
            pairs.append((name, "" if value is None else str(value)))
        else:
            unresolved.append(name)
    for entry in container.get("envFrom") or []:
        if "secretRef" in entry:
            unresolved.append(entry["secretRef"].get("name") or "envFrom.secretRef")
        elif "configMapRef" in entry:
            unresolved.append(entry["configMapRef"].get("name") or "envFrom.configMapRef")
    return pairs, unresolved


def probe_of(container):
    """(type, path, port, scheme, headers, description) of the first probe.

    The type is `http`, `tcp` or `exec`; the description names the field it came
    from so a failure prints the probe the manifest actually declares.
    """
    ports = {str(p.get("name")): p.get("containerPort") for p in container.get("ports") or []}
    for field in ("readinessProbe", "startupProbe", "livenessProbe"):
        probe = container.get(field) or {}
        where = field.replace("Probe", "")
        http = probe.get("httpGet")
        if http:
            raw_port = http.get("port")
            port = ports.get(str(raw_port)) if str(raw_port) in ports else raw_port
            if port is None:
                die(f"{field}.httpGet.port {raw_port!r} does not resolve through the container's ports {sorted(ports)}")
            headers = [f"{h.get('name')}: {h.get('value')}" for h in http.get("httpHeaders") or []]
            scheme = str(http.get("scheme") or "HTTP").lower()
            return ("http", str(http.get("path") or "/"), str(port), scheme, headers,
                    f"{where} httpGet {http.get('path') or '/'} on {port} ({scheme})")
        tcp = probe.get("tcpSocket")
        if tcp:
            raw_port = tcp.get("port")
            port = ports.get(str(raw_port)) if str(raw_port) in ports else raw_port
            if port is None:
                die(f"{field}.tcpSocket.port {raw_port!r} does not resolve through the container's ports {sorted(ports)}")
            return ("tcp", "", str(port), "", [], f"{where} tcpSocket port {raw_port} ({port})")
        if probe.get("exec"):
            # An exec probe is the container's own business; the container still
            # has to declare a port to talk to, which is what gets probed here.
            return ("exec", "", "", "", [], f"{where} exec probe (probed as TCP on the first port)")
    return ("", "", "", "", [], "")


targets = []
for doc in docs:
    if doc.get("kind") != "Deployment":
        continue
    pod = ((doc.get("spec") or {}).get("template") or {}).get("spec") or {}
    volumes = {v.get("name"): v for v in pod.get("volumes") or []}
    init_containers = pod.get("initContainers") or []
    for container in pod.get("containers") or []:
        kind = image_kind(container.get("image", ""))
        if kind is None:
            continue

        index = len(targets) + 1
        name = f"{doc['metadata']['name']}/{container.get('name')}"
        skip = []
        if fixture_skip:
            skip.append(fixture_skip)
        mounts = []      # (host dir, container path)
        tmpfs = []       # container paths
        mount_paths = set()

        pairs, unresolved = env_pairs(container)
        if unresolved:
            skip.append("env needs a cluster (valueFrom/envFrom: " + ", ".join(unresolved) + ")")

        # The relay image exits 1 without an exposed address and an auth secret
        # (its own defaults). An instance rendered without them - a fixture that
        # only exercises the render path - is therefore not runnable by
        # construction, and saying so beats waiting 180s for the crash.
        if kind == "relay":
            literals = dict(pairs)
            args_text = " ".join(str(part) for part in container.get("args") or [])
            lacks = [flag for flag, env_name in (("--exposed-address", "NB_EXPOSED_ADDRESS"),
                                                 ("--auth-secret", "NB_AUTH_SECRET"))
                     if not literals.get(env_name) and flag not in args_text]
            if lacks:
                skip.append("relay exits 1 without " + " and ".join(lacks) + " in the rendered env")

        # Every literal the substitution may see: the container's own values
        # first, then the init container's (that is the process the chart runs
        # envsubst in, and a name only it defines must not become empty).
        subst_env = dict(pairs)
        for init in init_containers:
            init_pairs, _ = env_pairs(init)
            for key, value in init_pairs:
                subst_env.setdefault(key, value)

        # The config the chart's envsubst init container produces - only when
        # that init container exists. Without it the pod mounts an empty dir and
        # the server fails on the missing file, which is what must be tested.
        config_template = None
        config_source = ""
        for init in init_containers:
            for mount in init.get("volumeMounts") or []:
                volume = volumes.get(mount.get("name")) or {}
                cm_name = (volume.get("configMap") or {}).get("name")
                if not cm_name:
                    continue
                cm = configmaps.get(cm_name) or {}
                for key, text in (cm.get("data") or {}).items():
                    if str(key).endswith((".tmpl", ".template")):
                        config_template, config_source = str(text), key
        if kind == "server":
            if config_template is None:
                for cm in configmaps.values():
                    for key, text in (cm.get("data") or {}).items():
                        if str(key).endswith((".tmpl", ".template")):
                            config_template, config_source = str(text), key
            if config_template is None:
                skip.append("no config template (envsubst init container) rendered")
            else:
                config_path = "/etc/netbird/config.yaml"
                argv = [str(part) for part in container.get("args") or []]
                for position, part in enumerate(argv):
                    if part in ("--config", "-c") and position + 1 < len(argv):
                        config_path = argv[position + 1]
                    elif part.startswith("--config="):
                        config_path = part.split("=", 1)[1]
                hostdir = os.path.join(work, f"target-{index}-config")
                os.makedirs(hostdir, exist_ok=True)
                with open(os.path.join(hostdir, os.path.basename(config_path)), "w") as handle:
                    handle.write(substitute(config_template, subst_env))
                mounts.append((hostdir, os.path.dirname(config_path)))

        for mount in container.get("volumeMounts") or []:
            volume = volumes.get(mount.get("name")) or {}
            path = str(mount.get("mountPath"))
            read_only = bool(mount.get("readOnly"))
            cm = volume.get("configMap")
            if cm:
                cm_doc = configmaps.get(cm.get("name"))
                if cm_doc is None:
                    if cm.get("optional"):
                        continue
                    skip.append(f"volume {mount.get('name')} projects the missing ConfigMap {cm.get('name')}")
                    continue
                hostdir = os.path.join(work, f"target-{index}-cm-{mount.get('name')}")
                os.makedirs(hostdir, exist_ok=True)
                for key, text in (cm_doc.get("data") or {}).items():
                    with open(os.path.join(hostdir, str(key)), "w") as handle:
                        handle.write("" if text is None else str(text))
                if path not in mount_paths:
                    mounts.append((hostdir, path))
                    mount_paths.add(path)
                continue
            if "emptyDir" in volume or "persistentVolumeClaim" in volume:
                # The pod gets a writable dir here; docker gets a tmpfs, never a
                # bind mount the container writes into (those cannot be removed
                # again on a Linux runner, and cleanup would fail the job after
                # the check itself passed).
                if not read_only and path not in mount_paths:
                    tmpfs.append(path)
                    mount_paths.add(path)
                continue
            skip.append(f"volume {mount.get('name')} needs a cluster to resolve")

        probe_kind, probe_path, probe_port, scheme, headers, probe_desc = probe_of(container)
        if probe_kind == "exec" and probe_port:
            # The exec command is the pod's own business; the port it guards is
            # what can be driven from outside.
            probe_kind = "tcp"
        if not probe_port:
            first = next((p for p in container.get("ports") or [] if p.get("containerPort")), None)
            if first is not None:
                probe_port = str(first["containerPort"])
                probe_desc = f"no probe -> TCP connect to {first.get('name') or first['containerPort']} ({probe_port})"
            else:
                skip.append("no container port and no probe to drive it")
        if not probe_kind and probe_port:
            probe_kind = "tcp"

        env_file = os.path.join(work, f"target-{index}.env")
        with open(env_file, "w") as handle:
            for key, value in pairs:
                handle.write(f"{key}={value}\n")

        security = container.get("securityContext") or {}
        read_only = "1" if security.get("readOnlyRootFilesystem") else "0"

        lines = [
            f"TARGET_NAME={quote(name)}",
            f"TARGET_KIND={quote(kind)}",
            f"TARGET_IMAGE={quote(str(container.get('image', '')))}",
            f"TARGET_SKIP={quote('; '.join(skip))}",
            f"TARGET_PROBE_KIND={quote(probe_kind)}",
            f"TARGET_PROBE_PATH={quote(probe_path)}",
            f"TARGET_PROBE_SCHEME={quote(scheme)}",
            f"TARGET_PROBE_PORT={quote(probe_port)}",
            f"TARGET_PROBE_RAW={quote(probe_desc)}",
            f"TARGET_READ_ONLY={quote(read_only)}",
            f"TARGET_ENV_FILE={quote(env_file)}",
            sh_array("TARGET_CMD", container.get("command") or []),
            sh_array("TARGET_ARGS", container.get("args") or []),
            sh_array("TARGET_PROBE_HEADERS", headers),
            sh_array("MOUNT_ARGS", [part for host, path in mounts for part in ("-v", f"{host}:{path}:ro")]),
            sh_array("TMPFS_ARGS", [part for path in tmpfs for part in ("--tmpfs", f"{path}:rw,mode=1777,size=512m")]),
        ]
        with open(os.path.join(work, f"target-{index}.sh"), "w") as handle:
            handle.write("\n".join(lines) + "\n")
        targets.append((index, name, kind, container.get("image"), skip, probe_desc))

with open(os.path.join(work, "count"), "w") as handle:
    handle.write(f"{len(targets)}\n")
for index, name, kind, image, skip, probe_desc in targets:
    state = "skip: " + skip[0] if skip else probe_desc or "?"
    print(f"     plan   {kind:<10} {image} [{name}] {state}")
if not targets:
    print("     plan   no NetBird container in this render")
PY
  then
    fail "the render could not be parsed"
  fi

  # OrbStack/macOS can serve a freshly rewritten bind mount a few hundred
  # milliseconds before the VM sees the new content (measured: a stale read on
  # the first docker run after a write). The containers below start right after
  # these files are written, so give the mount a moment.
  sleep 0.5

  count=$(cat "$work/count")
  for i in $(seq 1 "$count"); do
    # shellcheck source=/dev/null
    . "$work/target-$i.sh"
    target="$TARGET_NAME"
    if [ -n "$TARGET_SKIP" ]; then
      echo "     skip   $TARGET_IMAGE: $TARGET_SKIP"
      continue
    fi

    container="nb-ci-${run_id}-${scenario_index}-${i}"
    port_hint=$(free_port "$port_hint")
    host_port="$port_hint"
    port_hint=$((port_hint + 1))

    entrypoint=()
    argv=()
    if [ "${#TARGET_CMD[@]}" -gt 0 ]; then
      entrypoint=(--entrypoint "${TARGET_CMD[0]}")
      j=1
      while [ "$j" -lt "${#TARGET_CMD[@]}" ]; do
        argv+=("${TARGET_CMD[$j]}")
        j=$((j + 1))
      done
    fi
    argv+=( ${TARGET_ARGS[@]+"${TARGET_ARGS[@]}"} )

    read_only_args=()
    if [ "$TARGET_READ_ONLY" = "1" ]; then
      read_only_args=(--read-only)
    fi

    # The published port is picked before docker binds it, so a concurrent run
    # on a shared host can take it in between: retry on the next free port
    # instead of reporting that race as a chart failure.
    started=""
    for _ in 1 2 3 4 5; do
      if run_err=$(docker run -d --name "$container" \
          ${entrypoint[@]+"${entrypoint[@]}"} \
          ${read_only_args[@]+"${read_only_args[@]}"} \
          --env-file "$TARGET_ENV_FILE" \
          ${MOUNT_ARGS[@]+"${MOUNT_ARGS[@]}"} \
          ${TMPFS_ARGS[@]+"${TMPFS_ARGS[@]}"} \
          -p "127.0.0.1:${host_port}:${TARGET_PROBE_PORT}" \
          "$TARGET_IMAGE" ${argv[@]+"${argv[@]}"} 2>&1 >/dev/null); then
        started=1
        break
      fi
      case "$run_err" in
        *"port is already allocated"* | *"address already in use"*)
          docker rm -f "$container" >/dev/null 2>&1 || true
          host_port=$(free_port $((host_port + 1)))
          ;;
        *) break ;;
      esac
    done
    if [ -z "$started" ]; then
      fail "docker run failed: ${run_err:-unknown error}"
    fi

    echo "     start  $TARGET_IMAGE -> 127.0.0.1:${host_port}:${TARGET_PROBE_PORT} (${TARGET_PROBE_RAW})"

    # Assert, in order: still running, and the rendered readiness surface
    # answers - on two consecutive polls, so a port that is bound before the app
    # actually serves, or a container that dies right after binding, cannot pass
    # the gate. A container that has already exited is a failure, not a slow
    # start - waiting out the poll would hide the app's own error message.
    deadline=$((SECONDS + ${RUNTIME_CHECK_TIMEOUT:-180}))
    result=""
    answered=0
    while :; do
      if [ "$(docker inspect -f '{{.State.Running}}' "$container")" != "true" ]; then
        fail "the container exited (code $(docker inspect -f '{{.State.ExitCode}}' "$container")) instead of answering ${TARGET_PROBE_RAW}"
      fi
      result=""
      if [ "$TARGET_PROBE_KIND" = "http" ]; then
        url="http://127.0.0.1:${host_port}${TARGET_PROBE_PATH}"
        curl_args=()
        if [ "$TARGET_PROBE_SCHEME" = "https" ]; then
          url="https://127.0.0.1:${host_port}${TARGET_PROBE_PATH}"
          curl_args=(--insecure)
        fi
        for header in ${TARGET_PROBE_HEADERS[@]+"${TARGET_PROBE_HEADERS[@]}"}; do
          curl_args+=(-H "$header")
        done
        got=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 \
          ${curl_args[@]+"${curl_args[@]}"} "$url" 2>/dev/null || true)
        case "$got" in
          2?? | 3??) result="HTTP $got" ;;
        esac
      elif tcp_ok "$host_port"; then
        result="TCP connect"
      fi
      if [ -n "$result" ]; then
        answered=$((answered + 1))
        if [ "$answered" -ge 2 ]; then
          break
        fi
      else
        answered=0
      fi
      if [ "$SECONDS" -ge "$deadline" ]; then
        fail "${TARGET_PROBE_RAW} did not answer on two consecutive polls within ${RUNTIME_CHECK_TIMEOUT:-180}s"
      fi
      if [ "$answered" -gt 0 ]; then
        # Keep the two observations at least two seconds apart: a socket that
        # accepts while the process is still booting, and a container that dies
        # a moment later, must not pass as serving.
        sleep 2
      else
        sleep 1
      fi
    done
    if [ "$(docker inspect -f '{{.State.Running}}' "$container")" != "true" ]; then
      fail "the container answered and then exited (code $(docker inspect -f '{{.State.ExitCode}}' "$container"))"
    fi

    printf '%s\n' "$TARGET_KIND" >> "$kinds_seen"
    echo "OK     $scenario $TARGET_IMAGE ${TARGET_PROBE_RAW} -> ${result}"
    if [ "${GITHUB_ACTIONS:-}" != "true" ]; then
      docker logs "$container" 2>&1 | tail -3 | sed 's/^/     | /' || true
    fi

    docker rm -f "$container" >/dev/null
    container=""
  done

  rm -rf "$work" 2>/dev/null || true
  endgroup
done

# A fixture rename must not be able to shrink the gate silently: all five
# images have to have been started by something in this run.
missing=""
for kind in server management signal relay dashboard; do
  if ! grep -qx "$kind" "$kinds_seen"; then
    missing="${missing:+$missing }$kind"
  fi
done
if [ -n "$missing" ]; then
  echo "::error::no scenario exercised the image kind(s): $missing - the fixture set would leave them unchecked"
  echo "FAIL <fixture set> -> no scenario started: $missing"
  exit 1
fi

echo "runtime check passed for ${#scenarios[@]} scenario(s); image kinds exercised: $(sort -u "$kinds_seen" | tr '\n' ' ')"
