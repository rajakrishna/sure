# Homelab fork notes (zerotoidea)

This is Raja’s fork of [we-promise/sure](https://github.com/we-promise/sure) (AGPLv3).

**Live instance today:** Proxmox CT **104** — still runs `ghcr.io/we-promise/sure:stable` plus host mounts under `/opt/sure/overrides/` (Ollama tool fixes). Do **not** point production at this fork until a tagged custom image is built and smoke-tested.

## Goals
1. Improve assistant tool use for local Ollama (biggest/smallest, month totals) in-repo instead of fragile host overrides alone.
2. Build and publish our own image: `ghcr.io/rajakrishna/sure:<tag>`.
3. Cut CT 104 over to that image; keep Postgres/Redis volumes untouched.

## Deploy plan (when ready)
1. Develop on a branch (e.g. `homelab/ai-tools`) — port logic from CT 104 `/opt/sure/overrides/*.rb` into proper initializers / assistant config.
2. CI: GitHub Actions → build Dockerfile → push `ghcr.io/rajakrishna/sure:stable` (and git sha tags). Repo must allow GHCR packages for this account.
3. On CT 104: snapshot DB (or Sure backup), change `compose.yml` web+worker `image:` to our GHCR image, `docker compose pull && up -d`.
4. Smoke: login, MCP, chat “biggest expense in August”, Sidekiq worker healthy.
5. Keep `upstream` remote to `we-promise/sure` and rebase/merge periodically (AGPL + security).

## Current production overrides (reference — migrate into this repo)
On CT 104 `/opt/sure/overrides/`:
- `zz_get_transactions_month_compat.rb` — month arg + local tool rules
- `zz_ollama_chat_tools.rb` / `zz_ollama_think_false.rb` — Ollama tools + `think:false`
- `zz_mcp_finance_extras.rb` — extra MCP tools

## Public URL
https://sure.zerotoidea.com (TinyAuth / gateway — see homelab-docs inventory).
