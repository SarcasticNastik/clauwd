#!/usr/bin/env bash
# Install cc-remote by symlinking files from this repo into the standard
# user locations and enabling the systemd user service.
#
# Idempotent: safe to run multiple times. Existing symlinks pointing at this
# repo are left alone; conflicting files are backed up to <path>.bak-<ts>.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/bin"
SERVICE_SRC="$REPO_DIR/systemd/claude-remote.service"

BIN_DST="$HOME/.local/bin"
SERVICE_DST_DIR="$HOME/.config/systemd/user"
SERVICE_DST="$SERVICE_DST_DIR/claude-remote.service"
SERVICE_NAME="claude-remote.service"

CLAUDE_JSON="$HOME/.claude.json"

log() { echo "[install] $*"; }
die() { echo "[install] ERROR: $*" >&2; exit 1; }

# Check prerequisites
command -v claude >/dev/null 2>&1 || die "claude not found in PATH"
command -v systemctl >/dev/null 2>&1 || die "systemctl not found; systemd is required"

# Create target directories
mkdir -p "$BIN_DST" "$SERVICE_DST_DIR"

# Symlink a single file: $1 = source, $2 = target
link_file() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink -f "$dst")"
    if [[ "$current" == "$(readlink -f "$src")" ]]; then
      log "already linked: $dst"
      return
    fi
    log "replacing existing symlink: $dst"
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    local backup="${dst}.bak-$(date +%Y%m%d%H%M%S)"
    log "backing up existing file: $dst -> $backup"
    mv "$dst" "$backup"
  fi
  ln -s "$src" "$dst"
  log "linked: $dst -> $src"
}

# Link binaries
for f in "$BIN_SRC"/*; do
  link_file "$f" "$BIN_DST/$(basename "$f")"
  chmod +x "$f"
done

# Link systemd unit
link_file "$SERVICE_SRC" "$SERVICE_DST"

# Ensure workspace trust is accepted for $HOME so the non-interactive service
# can start claude remote-control without hitting the trust dialog.
if [[ -f "$CLAUDE_JSON" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$CLAUDE_JSON" "$HOME" <<'PY'
import json, sys
path, home = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
projects = data.setdefault("projects", {})
entry = projects.setdefault(home, {})
if entry.get("hasTrustDialogAccepted") is not True:
    entry["hasTrustDialogAccepted"] = True
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"[install] trusted workspace: {home}")
else:
    print(f"[install] workspace already trusted: {home}")
PY
  else
    log "WARNING: python3 not found; skipping workspace trust setup"
    log "  you may need to run 'claude' in $HOME once to accept the trust dialog"
  fi
else
  log "NOTE: $CLAUDE_JSON not found; workspace trust will be set on first claude run"
fi

# Reload and enable the service
log "reloading systemd user daemon"
systemctl --user daemon-reload

log "enabling and starting $SERVICE_NAME"
systemctl --user enable --now "$SERVICE_NAME"

# Run tests
log "running test suite"
if "$BIN_DST/cc-remote-test"; then
  log "install complete"
else
  die "test suite failed after install"
fi
