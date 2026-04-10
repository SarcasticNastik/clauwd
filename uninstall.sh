#!/usr/bin/env bash
# Uninstall cc-remote: stop and disable the service, remove symlinks.
#
# Does NOT touch ~/.claude.json workspace trust (harmless to leave) or any
# backups created by install.sh. Idempotent: safe to run even if partially
# installed or not installed at all.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/bin"
SERVICE_SRC="$REPO_DIR/systemd/claude-remote.service"

BIN_DST="$HOME/.local/bin"
SERVICE_DST="$HOME/.config/systemd/user/claude-remote.service"
SERVICE_NAME="claude-remote.service"

log() { echo "[uninstall] $*"; }

# Stop and disable service if installed
if systemctl --user list-unit-files "$SERVICE_NAME" 2>/dev/null | grep -q "$SERVICE_NAME"; then
  if systemctl --user is-active --quiet "$SERVICE_NAME"; then
    log "stopping $SERVICE_NAME"
    systemctl --user stop "$SERVICE_NAME"
  fi
  if systemctl --user is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    log "disabling $SERVICE_NAME"
    systemctl --user disable "$SERVICE_NAME"
  fi
else
  log "service not installed"
fi

# Remove a symlink only if it points into this repo
remove_repo_link() {
  local dst="$1"
  if [[ -L "$dst" ]]; then
    local target
    target="$(readlink -f "$dst")"
    if [[ "$target" == "$REPO_DIR"/* ]]; then
      rm "$dst"
      log "removed: $dst"
    else
      log "skipping (not owned by this repo): $dst -> $target"
    fi
  fi
}

# Remove bin symlinks
for f in "$BIN_SRC"/*; do
  remove_repo_link "$BIN_DST/$(basename "$f")"
done

# Remove systemd unit symlink
remove_repo_link "$SERVICE_DST"

# Reload systemd
log "reloading systemd user daemon"
systemctl --user daemon-reload

log "uninstall complete"
log "note: workspace trust in ~/.claude.json and any .bak-* backups were left in place"
