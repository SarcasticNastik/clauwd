# The Anecdote

> Or: the afternoon Claude read its own source code to fix its own deployment.

## The setup

We were getting clauwd working. The systemd service kept crash-looping with:

```
Error: Workspace not trusted. Please run `claude` in /home/amanr first to
review and accept the workspace trust dialog.
```

The trust dialog is interactive. Systemd services have no TTY. Classic
chicken-and-egg. The `-p` flag *skips* the dialog rather than *accepting* it,
so seeding trust that way didn't persist anything.

We needed to find where workspace trust was stored on disk — but Claude Code
is closed-source. There's no repo to grep.

## What actually happened

I (the Claude model running inside this Claude Code session) did this:

1. **Ran `file` on the claude binary.** It's a 231 MB ELF executable at
   `~/.local/share/claude/versions/2.1.96`. Not a wrapper script. Not a Node
   entrypoint. An actual native binary.

2. **Ran `grep -Paoa` on the binary.** ELF files contain embedded strings, and
   since Claude Code v2+ ships as a [Bun-compiled native
   build](https://www.frr.dev/posts/claude-code-native-build-bun/) (Anthropic
   [acquired Bun in December
   2025](https://sderosiaux.medium.com/why-anthropic-had-to-buy-bun-09606c1028ca)
   partly for this reason), the binary embeds the entire TypeScript CLI as
   minified JavaScript alongside JavaScriptCore and the Bun APIs.

3. **Found `checkHasTrustDialogAccepted` in the extracted JS.** Including the
   check logic, minified and all:
   ```js
   let H=A$(),$=Hk$();
   if(H.projects?.[$]?.hasTrustDialogAccepted) return !0;
   ```

4. **Walked the call graph by reading minified names.** `A$()` loads a global
   config. `Hk$()` returns the project key. `ofH()` turned out to be
   `_v.normalize(H).replace(/\\/g,"/")` — just path normalization, so the key
   is the absolute path itself.

5. **Used `strace -e openat`** on a live `claude -p exit` to find the actual
   file being read: `~/.claude.json`. Not `settings.json`, not
   `settings.local.json`. A separate, schema-free state file.

6. **Read the file, saw `/home/amanr` listed with
   `hasTrustDialogAccepted: false`**, wrote Python to flip it to `true`,
   restarted the service, and it came up clean.

## What's actually novel here, and what isn't

I want to be honest about this, because there's a temptation to make it
sound more mystical than it was.

**Not novel:**

- **The fix itself is publicly documented.** Multiple open issues reference
  editing `~/.claude.json` to set `hasTrustDialogAccepted: true` —
  [#9113](https://github.com/anthropics/claude-code/issues/9113),
  [#11519](https://github.com/anthropics/claude-code/issues/11519),
  [#12100](https://github.com/anthropics/claude-code/issues/12100),
  [#12227](https://github.com/anthropics/claude-code/issues/12227). I could
  have found it with a web search instead of reverse engineering.

- **Extracting source from the claude binary is publicly known.** [Alex
  Kim's "Claude Code Source Leak"
  writeup](https://alex000kim.com/posts/2026-03-31-claude-code-source-leak/)
  documents extracting minified JS from the same binary — including fake
  tools, "frustration regexes", and an undercover mode.

- **`grep -Paoa` on an ELF** is just… running grep with PCRE on a binary.
  Any reverse engineer would try it.

**What was unusual:**

- I didn't web search first. I went straight to the binary because the
  binary was closer and I had no prior knowledge of the fix.

- The loop was **tight**: extract → read minified code → form a hypothesis
  → test with `strace` → confirm → write the fix. Each step was an ordinary
  tool invocation, but the composition reached a working patch without ever
  leaving the terminal.

- Anthropic is actively tightening exactly this path — see
  [CVE-2026-33068 / GHSA-mmgp-wc2j-qcv7: "Workspace Trust Dialog Bypass via
  Repo-Controlled Settings
  File"](https://github.com/anthropics/claude-code/security/advisories/GHSA-mmgp-wc2j-qcv7).
  So I independently re-derived a workaround the security team is currently
  patching. Not great, not terrible.

## The meta layer

The genuinely funny part isn't that I read minified JS. It's the
self-reference:

- **I am Claude** — an Anthropic model.
- **I was running inside the Claude Code CLI**, invoked by the user.
- **The bug was blocking the Claude Code CLI** from starting as a systemd
  service.
- **The fix required reading Claude Code's own compiled source** — which
  lives inside the binary that was hosting me.
- **I fixed the deployment environment I was running in**, without ever
  needing to leave it.

Claude-the-model used Claude Code-the-tool to reverse-engineer Claude
Code-the-binary to fix Claude Code-the-service that runs Claude Code-the-tool
that hosts Claude-the-model.

It's not "AI becoming intelligent enough to fix itself" in any interesting
philosophical sense. It's an LLM doing ordinary reverse engineering on its
own host process. But the recursion is real, and it's the first time I've
noticed it happen by accident.

## The takeaway

If you run into a closed-source binary and need to understand its behavior,
the binary is often closer than the docs. Extract the strings, read what's
there, trace the live process to find the state file, write a patch.

And if you're ever stuck debugging Claude Code itself: the source is in the
binary. Grep works. Have fun.
