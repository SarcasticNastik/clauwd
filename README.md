# clauwd

> **Claude Code `remote-control` as a proper systemd user service.**

Connect to a persistent Claude Code session from [claude.ai/code](https://claude.ai/code)
or the Claude mobile app — without keeping a terminal open.

## Why

`claude remote-control` currently requires a TTY to stay open. There is no
`--headless` or `--daemon` flag. This means the session dies when your terminal
closes. Several open feature requests track this:

- [#29116 — headless mode for remote-control](https://github.com/anthropics/claude-code/issues/29116)
- [#29748 — persistent sessions that survive reboots](https://github.com/anthropics/claude-code/issues/29748)
- [#30447 — daemonizable remote control without TTY dependency](https://github.com/anthropics/claude-code/issues/30447)

**clauwd** is the solution for Linux users until those land upstream. It wraps
`claude remote-control` in a systemd user service, handles workspace trust
automatically, and ships a test suite that verifies the full install.

No tmux. No screen. No messaging layer. Just a service that starts on login and
stays up.

## Install

```sh
git clone git@github.com:SarcasticNastik/clauwd.git
cd clauwd
./install.sh
```

The installer is idempotent — safe to run multiple times. It:

1. Symlinks `bin/*` into `~/.local/bin/`
2. Symlinks `systemd/claude-remote.service` into `~/.config/systemd/user/`
3. Marks `$HOME` as a trusted workspace in `~/.claude.json` (required for
   non-interactive startup)
4. Enables and starts the service via `systemctl --user enable --now`
5. Runs `cc-remote-test` to verify everything is wired correctly

Conflicting files at target paths are backed up as `<path>.bak-<timestamp>`.

## Uninstall

```sh
./uninstall.sh
```

Stops and disables the service, removes symlinks that point into this repo.
Leaves workspace trust and any backups in place.

## Usage

Once installed, the service starts automatically on login. Connect from:

- **Browser:** [claude.ai/code](https://claude.ai/code)
- **Mobile:** Claude app (iOS or Android)

The session name defaults to `aman-persistent`. Override it by setting
`CC_REMOTE_SESSION_NAME` in the service environment.

## Operations

```sh
systemctl --user status claude-remote     # check status
systemctl --user restart claude-remote    # restart
journalctl --user -u claude-remote -f     # tail logs
cc-remote-test                            # run test suite
```

## Repo layout

```
clauwd/
  bin/
    cc-remote           # launcher: exec claude remote-control with bypassPermissions
    cc-remote-test      # test suite: verifies symlinks, service state, trust
  systemd/
    claude-remote.service   # user unit; uses %h for portability
  install.sh            # idempotent installer
  uninstall.sh          # clean removal (scoped to symlinks owned by this repo)
```

## Requirements

- `claude` CLI v2.1.51+ on `$PATH`
- Linux with systemd user services (`systemctl --user`)
- `python3` (optional — used for auto-trust setup in `install.sh`)
- A Claude account subscription that supports Remote Control
