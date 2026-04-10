# cc-remote

Always-on Claude Code `remote-control` session as a systemd user service, so
you can connect to it from claude.ai/code or the Claude mobile app without
keeping a terminal open.

## Layout

```
cc-remote/
  bin/
    cc-remote         # launcher: exec claude remote-control
    cc-remote-test    # test suite: verifies install and service state
  systemd/
    claude-remote.service   # systemd user unit (uses %h for portability)
  install.sh          # symlinks files into ~/.local/bin and ~/.config/systemd/user
  uninstall.sh        # removes symlinks, stops and disables service
```

## Install

```
./install.sh
```

The installer is idempotent. It:

1. Symlinks `bin/*` into `~/.local/bin/`
2. Symlinks `systemd/claude-remote.service` into `~/.config/systemd/user/`
3. Marks `$HOME` as a trusted workspace in `~/.claude.json` so the service
   can start non-interactively
4. Runs `systemctl --user daemon-reload` + `enable --now`
5. Runs `cc-remote-test` to verify everything

Conflicting files (non-symlinks) at target paths are backed up as
`<path>.bak-<timestamp>`.

## Uninstall

```
./uninstall.sh
```

Stops and disables the service, removes symlinks that point into this repo.
Leaves workspace trust and backups in place.

## Usage

Once installed, the service runs automatically. Connect to the session from:

- [claude.ai/code](https://claude.ai/code) in any browser
- The Claude mobile app

Look for the session named `aman-persistent` (override with
`CC_REMOTE_SESSION_NAME` in the service environment).

## Operations

```
systemctl --user status claude-remote     # check status
systemctl --user restart claude-remote    # restart
journalctl --user -u claude-remote -f     # tail logs
cc-remote-test                            # run test suite
```

## Requirements

- `claude` CLI on `$PATH`
- `systemd` with user services (`systemctl --user`)
- `python3` (optional, only for auto-trust during install)
- A Claude account subscription that supports remote control
