# Server Observability

Production-oriented Grafana + Prometheus + exporter stack for a single Ubuntu home server.

## Design goals

- Keep public exposure outside this repo.
- Bind host-facing services to `127.0.0.1` so they are not reachable on the LAN.
- Run exporters in Docker while still reading the underlying host's `/proc`, `/sys`, and `/`.
- Keep the repo easy to run directly on the server after cloning it.
- Start with host health metrics first, then layer dashboards and alerts on top.
- Keep exporter endpoints off the host network entirely unless localhost access is explicitly useful.

## Architecture

```text
existing reverse proxy
  -> 127.0.0.1:3000 grafana

grafana
  -> prometheus:9090

prometheus
  -> node-exporter:9100
  -> process-exporter:9256

host
  -> 127.0.0.1:9090 prometheus
```

### Why Docker here

Docker Compose gives you:

- a reproducible local dev environment,
- a clean deploy target on Ubuntu,
- pinned image versions,
- isolated service networking,
- a straightforward path to backup and restore Docker volumes.

## Host monitoring correctness

Running `node_exporter` inside a container is only correct if it reads the host namespaces and filesystems, not the container's. This repo handles that by:

- mounting host `/proc` to `/host/proc`,
- mounting host `/sys` to `/host/sys`,
- mounting host `/` to `/host/root`,
- setting `pid: host`,
- pointing `node_exporter` at those host paths.

That means CPU, memory, load, filesystem, thermal sensors, and systemd state come from the Ubuntu server, not the exporter container.

For named process visibility, `process-exporter` also runs with `pid: host` and reads the host `/proc`.

Only Grafana and Prometheus are published to the host, and both are bound to `127.0.0.1`. Exporters are not published at all, so they are reachable only from the internal Docker network.

## Repository layout

```text
.
|-- docker-compose.yml
|-- .env.example
|-- Makefile
|-- ops
|   |-- grafana
|   |   |-- dashboards
|   |   `-- provisioning
|   |-- process-exporter
|   `-- prometheus
|-- .github
`-- scripts
```

## First-run setup

1. Copy the environment file:

   ```bash
   make init
   ```

2. Edit `.env`:

   - set `GF_DOMAIN`,
   - set `GF_SERVER_ROOT_URL`,
   - set `GF_SECURITY_CSRF_TRUSTED_ORIGINS` to the public Grafana URL,
   - set a strong `GF_ADMIN_PASSWORD`.

3. Validate the Compose definition:

   ```bash
   make validate
   ```

4. Start the stack:

   ```bash
   make up
   ```

5. Point your existing reverse proxy at `http://127.0.0.1:3000`, or test directly on the server at `http://127.0.0.1:3000`.

## Server deployment

SSH to the server, clone the repo, and run it there:

```bash
git clone <repo-url>
cd Server-Observability
make init
make validate
make up
```

Updates are the same pattern:

```bash
git pull
make validate
make up
```

## Make targets

Use the `Makefile` for the common lifecycle commands:

- `make init`
- `make validate`
- `make validate-ci`
- `make up`
- `make down`
- `make restart`
- `make ps`
- `make logs`
- `make pull`

## CI

GitHub Actions validates the repo on pushes to `main` and on pull requests. The workflow is at `.github/workflows/ci.yml` and runs:

- `shellcheck` on the `scripts/` directory,
- `docker compose config`,
- `promtool check config` for Prometheus,
- `promtool check rules` for alert rules,
- `jq` validation for the provisioned Grafana dashboard JSON.

## Integration boundary

This repo does not manage the reverse proxy. It assumes you already have one and only provides localhost-bound upstreams for it to target.

Example upstream target:

- Grafana: `http://127.0.0.1:3000`

Avoid publishing Grafana, Prometheus, or exporter ports on `0.0.0.0`.
If you never want direct local access to Prometheus, remove its `ports:` mapping entirely and let Grafana talk to it only over the Compose network.

Your reverse proxy must forward the original host and scheme to Grafana. In practice that usually means forwarding:

- `Host`
- `X-Forwarded-Proto`
- `X-Forwarded-For`
- `X-Forwarded-Host`

## Troubleshooting

If every panel shows `origin not allowed`, Grafana is rejecting requests before they reach Prometheus. Check these in order:

1. `GF_SERVER_ROOT_URL` must exactly match the public URL you use in the browser.
2. `GF_DOMAIN` should match the public hostname.
3. `GF_SECURITY_CSRF_TRUSTED_ORIGINS` should include the public Grafana URL, for example `https://grafana.example.com`.
4. Your reverse proxy must preserve or forward the original `Host` header and set `X-Forwarded-Proto` and `X-Forwarded-Host`.

After changing `.env`, restart Grafana with:

```bash
make down
make up
```

## Process metrics note

`node_exporter` does not give you named-process dashboards like "show nginx, sshd, and docker memory usage". It gives system-wide process counters. For per-process grouping, this repo includes `process-exporter`.

The starter config groups processes by command name:

```yaml
process_names:
  - name: "{{.Comm}}"
    cmdline:
      - '.+'
```

That is broad and useful for discovery, but on busy servers it can create high metric cardinality. Once you know what you care about, tighten it to named groups such as `sshd`, `docker`, `nginx`, `tailscaled`, and so on.

## Suggested production hardening

- Keep Grafana behind HTTPS on your existing reverse proxy.
- Restrict Prometheus access to SSH tunnelling or localhost only.
- Wire the included Prometheus rules into Alertmanager or your notification path.
- Back up the Docker volumes for Grafana and Prometheus.
- Add alerting rules for disk, memory, high load, and exporter down.
- Replace the default Grafana admin password immediately.
- Consider adding a dedicated container update process instead of ad hoc image upgrades.

## Recommended next steps

1. Bring the stack up locally and confirm the dashboard loads.
2. Clone the repo on the Ubuntu server and start it there.
3. Confirm your existing reverse proxy reaches only `127.0.0.1:3000`.
4. Refine `ops/process-exporter/process-exporter.yml` for the specific processes you care about.
5. Add alert rules once the baseline metrics look correct.
