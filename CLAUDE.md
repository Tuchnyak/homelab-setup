# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A documentation-only project: a comprehensive, step-by-step guide for setting up a multi-purpose
home server ("Homelab") on a single machine. There is no source code, no build system, no tests —
just Markdown (and one static HTML landing page). The guide is written in Russian; a finished
English translation is maintained in parallel under `release/`.

## Document pipeline (important — files are not independent)

Content flows through three stages, each less "raw" than the last. When asked to edit "the guide,"
first confirm which stage is meant — the same chapter/topic exists in multiple files at different
levels of polish and they are edited independently, not auto-synced:

1. **`00_additional_context.md` / `01_spec.md`** — the original planning spec: user profile, hardware
   constraints, and the architectural decisions (and rationale) behind the whole setup. Reference
   material for *why* the guide makes certain choices; not itself published.
2. **`homelab-setup-plan-current.md`** — the active working draft (Russian). This is where new
   content is drafted and restructured. The README explicitly notes it "may contain raw and
   unstructured text" — treat it as a work in progress, not a style reference.
3. **`release/ru-homelab-setup.md` and `release/en-homelab-setup.md`** — finalized,
   publication-ready versions. `ru-` is the polished counterpart of the working draft; `en-` is its
   English translation. These two files should stay in sync with each other chapter-for-chapter.
   The release files currently cover Chapters 0–6 plus an Appendices section; the working draft has
   already progressed further (through Chapter 8), so the releases lag the draft by design until
   that material is finalized and translated.

`docs/index.html` is a plain static landing page (for GitHub Pages) that links out to the README,
both release files, and the license on GitHub — it has no build step, just hand-edit the HTML.

## Content structure

Chapters are numbered (`## Глава N` / `## Chapter N`) and build on each other sequentially, e.g.:

- Ch. 0–1: Hardware prep, Ubuntu Server LTS installation with **Btrfs**
- Ch. 2: Security hardening (SSH keys, UFW, fail2ban)
- Ch. 3: Foundation for services (`/srv` layout for persistent data)
- Ch. 4: Networking / file access (Samba)
- Ch. 5: Deploying core services via **Podman** / `podman-compose` behind **Nginx Proxy Manager**
- Ch. 6: Backup strategy
- Ch. 7 (draft only): Deploying custom Java/Kotlin apps with **Kamal**
- Ch. 8 (draft only): Additional/optional services

Key architectural decisions baked into the guide (see `00_additional_context.md` §4 for full
rationale before proposing alternatives):

- Podman (rootless, systemd-native) instead of Docker.
- Hybrid architecture: minimal bare-metal OS, everything else runs in containers.
- All persistent container data lives under a centralized `/srv` on the host, volume-mounted in.
- Nginx Proxy Manager as the single HTTPS ingress point for all services.
- Kamal (not `podman-compose`) specifically for the user's own application deployments, to mirror a
  real build → push → deploy CI/CD workflow.

## Server access (for live administration tasks)

Beyond editing the guide, this repo is also used as the base for hands-on administration of the
actual homelab server. SSH aliases are configured in `~/.ssh/config`:

- `ssh homeserver` — direct connection over the local network (`192.168.15.100`).
- `ssh homebird` — connection via Netbird VPN (`homeserver.netbird.cloud`), for access when not on
  the local network.

Both aliases use the same user (`tuchnyak`) and key (`~/.ssh/homeserver-key`). Prefer `homeserver`
when on the LAN; fall back to `homebird` otherwise. When asked to check or change something on "the
server," this is the target — cross-reference the relevant chapter of `homelab-setup-plan-current.md`
or `release/ru-homelab-setup.md` for the expected/intended state before making live changes.

The private key is passphrase-protected and not preloaded into `ssh-agent`. If `ssh homeserver`
fails with `Permission denied (publickey)`, check `ssh-add -l` first — if the agent has no
identities, the fix is to load it, which requires the passphrase and thus an interactive prompt:
ask the user to run `! ssh-add ~/.ssh/homeserver-key` themselves rather than trying to work around
it non-interactively.

## Editing conventions

- Keep new prose consistent with the surrounding chapter's language (Russian in
  `01_spec.md`/`homelab-setup-plan-current.md`/`release/ru-…`, English only in `release/en-…`).
- Command-line examples in the guide use fenced code blocks with inline `#` comments explaining each
  step — match that pattern rather than terse uncommented commands.
- Licensed under CC BY-NC 4.0 (see `LICENSE.md`) — attribution and non-commercial terms apply to any
  content reused from here.
