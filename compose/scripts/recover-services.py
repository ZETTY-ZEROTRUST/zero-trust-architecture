#!/usr/bin/env python3
"""Recover stopped ZETTY services without exporting existing core credentials."""
from __future__ import annotations
import hashlib
import json
import os
import re
from pathlib import Path
import secrets
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
TARGETS = ("nginx", "redis-events", "outbox-relay", "event-indexer", "prometheus", "mysqld-exporter")
CORE = ("auth", "api", "bff", "mysql", "kms", "redis-session", "elasticsearch", "cadvisor")


def checked(command, label, data=None):
    result = subprocess.run(command, input=data, capture_output=True, text=True, timeout=120)
    if result.returncode:
        # Diagnostics can contain SQL or environment values. Never echo them.
        raise RuntimeError(f"{label} failed, exit={result.returncode}; raw diagnostics suppressed")
    print(label + ": OK", flush=True)
    return result.stdout


def describe(service):
    # Env / Health.Log 수집 없이 허용된 상태와 mount 필드만 읽는다.
    template = (
        '{"status":{{json .State.Status}},"exit_code":{{.State.ExitCode}},'
        '"health":{{if .State.Health}}{{json .State.Health.Status}}{{else}}null{{end}},'
        '"container_id":{{json .Id}},"mounts":{{json .Mounts}}}'
    )
    raw = checked(["docker", "inspect", "--format", template, "zetty-" + service + "-1"],
                  "Inspect " + service)
    state = json.loads(raw)
    state["mounts"] = [
        {"type": m["Type"], "source": m["Source"], "destination": m["Destination"],
         "volume": m.get("Name")} for m in state["mounts"]
    ]
    return state


def ready(state):
    """healthcheck가 있는 서비스는 healthy까지 기다린다."""
    return state["status"] == "running" and state["health"] in (None, "healthy")


def protected_write(path, content, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x") as output:
        os.chmod(path, mode)
        output.write(content)


def prepare_secrets():
    base = ROOT / ".secrets"
    base.mkdir(exist_ok=True, mode=0o700)
    os.chmod(base, 0o700)
    paths = {name: base / "files" / name for name in
             ("relay_db", "indexer_db", "redis_relay", "redis_indexer", "redis_admin")}
    marker = base / "recovery.state.json"
    if marker.exists():
        if not all(p.is_file() for p in paths.values()) or not (base / "recovery.env").is_file():
            raise RuntimeError("Incomplete recovery files; refusing to rotate credentials implicitly")
        values = {name: p.read_text().strip() for name, p in paths.items()}
        # Only our newly generated exporter credential is consumed by the repair process.
        line = (base / "recovery.env").read_text().strip()
        if not line.startswith("EXPORTER_PASSWORD="):
            raise RuntimeError("Unexpected recovery environment format")
        values["exporter"] = line.split("=", 1)[1]
    else:
        if any(p.exists() for p in paths.values()) or (base / "recovery.env").exists():
            raise RuntimeError("Existing runtime files detected; refusing to overwrite them")
        values = {name: secrets.token_urlsafe(32) for name in (*paths, "exporter")}
        for name, path in paths.items():
            protected_write(path, values[name], 0o644)
        protected_write(base / "recovery.env", "EXPORTER_PASSWORD=" + values["exporter"] + "\n")
        protected_write(marker, json.dumps({"version": 1, "scope": list(TARGETS)}) + "\n")
    if not all(re.fullmatch(r"[A-Za-z0-9_-]+", v) for v in values.values()):
        raise RuntimeError("Generated credential format validation failed")
    sha = lambda value: hashlib.sha256(value.encode()).hexdigest()
    acl = (
        "user default off\n"
        f"user admin on #{sha(values['redis_admin'])} ~* &* +@all\n"
        "user healthcheck on nopass -@all +ping\n"
        f"user zetty-relay on #{sha(values['redis_relay'])} resetkeys resetchannels -@all +ping +client|setinfo +xadd ~zetty:security-events\n"
        f"user zetty-indexer on #{sha(values['redis_indexer'])} resetkeys resetchannels -@all +ping +client|setinfo +xreadgroup +xack +xautoclaim +xgroup|create +xpending +xinfo +xtrim ~zetty:security-events (+xadd ~zetty:security-events:dlq)\n"
    )
    acl_path = base / "redis-events/users.acl"
    acl_path.parent.mkdir(parents=True, exist_ok=True)
    acl_path.write_text(acl)
    os.chmod(acl_path, 0o644)
    sql = []
    for name, key in (("zetty_relay", "relay_db"), ("zetty_indexer", "indexer_db"), ("exporter", "exporter")):
        password = values[key]
        sql.append(f"CREATE USER IF NOT EXISTS '{name}'@'%' IDENTIFIED BY '{password}';")
        sql.append(f"ALTER USER '{name}'@'%' IDENTIFIED BY '{password}';")
    sql += [
        "GRANT SELECT ON zeti_db.security_event_outbox TO 'zetty_relay'@'%';",
        "GRANT UPDATE (status, lease_owner, lease_until, attempts, published_at) ON zeti_db.security_event_outbox TO 'zetty_relay'@'%';",
        "GRANT SELECT, INSERT ON zeti_db.security_event_receipt TO 'zetty_indexer'@'%';",
        "GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';",
        "ALTER USER 'exporter'@'%' WITH MAX_USER_CONNECTIONS 3;",
    ]
    # Root credential stays inside the existing MySQL container; never returned or copied.
    checked(["docker", "exec", "-i", "zetty-mysql-1", "sh", "-c",
             'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mysql --user=root --batch --skip-column-names'],
             "Align dedicated relay/indexer/exporter DB accounts", "\n".join(sql) + "\n")
    print("Generated runtime files and dedicated service credentials; core credentials retained", flush=True)


def compose_base():
    command = ["docker", "compose", "--project-directory", str(ROOT), "-f", str(ROOT / "compose.yaml")]
    original = ROOT / ".secrets/env"
    if original.is_file():
        command += ["--env-file", str(original)]
    command += ["--env-file", str(ROOT / ".secrets/recovery.env"), "--profile", "analysis", "--profile", "observability"]
    return command


def main():
    os.umask(0o077)
    before = {name: describe(name) for name in CORE}
    tls = ROOT / "tls"
    expected = ("server.crt", "server.key", "ca.crt", "ca.key")
    present = [(tls / name).is_file() for name in expected]
    if any(present) and not all(present):
        raise RuntimeError("Partial TLS setup exists; refusing to overwrite keys")
    if not all(present):
        checked(["bash", str(ROOT / "scripts/gen-tls.sh")], "Generate current-directory local TLS")
    prepare_secrets()
    command = compose_base()
    checked(command + ["config", "--quiet"], "Validate current Compose")
    checked(command + ["up", "-d", "--no-build", "--no-deps", "--force-recreate", "--wait", "--wait-timeout", "60",
                       "redis-events", "nginx", "prometheus"], "Recreate file-dependent infrastructure")
    checked(command + ["up", "-d", "--no-build", "--no-deps", "--force-recreate",
                       "outbox-relay", "event-indexer", "mysqld-exporter"], "Recreate pipeline and exporter")
    checked(["docker", "exec", "zetty-nginx-1", "nginx", "-t"], "Validate nginx configuration")
    statuses = {}
    for attempt in range(12):
        statuses = {name: describe(name) for name in TARGETS}
        if all(ready(s) for s in statuses.values()):
            if attempt >= 1:
                break
        time.sleep(2)
    if not all(ready(s) for s in statuses.values()):
        raise RuntimeError("A recovered service is not running/healthy; inspect safe status diagnostics")
    after = {name: describe(name) for name in CORE}
    if any(before[name]["container_id"] != after[name]["container_id"] for name in CORE):
        raise RuntimeError("A core container changed unexpectedly")
    if any(not ready(s) for s in after.values()):
        raise RuntimeError("A previously healthy core container stopped")
    for name, state in statuses.items():
        if any("/zetty-wt/" in m["source"] for m in state["mounts"]):
            raise RuntimeError("A recovered service still references the old worktree")
    curl = ["curl", "--silent", "--show-error", "--max-time", "10",
            "--cacert", str(tls / "ca.crt"), "--output", "/dev/null", "--write-out", "%{http_code}"]
    codes = {route: checked(curl + ["https://127.0.0.1:8443" + route], "HTTPS " + route).strip()
             for route in ("/users/me", "/.well-known/jwks.json")}
    if codes["/users/me"] != "401" or codes["/.well-known/jwks.json"] != "200":
        raise RuntimeError("Unexpected HTTPS route status")
    checked(["docker", "exec", "zetty-prometheus-1", "wget", "-qO-", "http://127.0.0.1:9090/-/ready"],
            "Prometheus readiness")
    metrics = checked(["docker", "exec", "zetty-prometheus-1", "wget", "-qO-",
                       "http://mysqld-exporter:9104/metrics"], "Exporter endpoint")
    mysql_up = any(line.strip() == "mysql_up 1" for line in metrics.splitlines())
    if not mysql_up:
        raise RuntimeError("MySQL exporter is running but cannot collect MySQL metrics")
    report = {"version": 1, "recovered": statuses,
              "core_preserved": {name: {"same_container": True, "status": state["status"],
                                       "health": state["health"]} for name, state in after.items()},
              "https_statuses": codes, "mysql_up": mysql_up,
              "tls": "local CA validated by curl; key material excluded",
              "secrets": "new dedicated service credentials in .secrets; core env not exported",
              "expected_completed_job": "kms-init exit 0",
              "remaining": "Original core .secrets/env is absent; use recovery.env only for the listed services"}
    destination = ROOT.parent / "docs/star/results/Z-06-runtime-recovery.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + "\n")
    print("Recovered all six stopped services; eight core containers preserved", flush=True)


if __name__ == "__main__":
    main()
