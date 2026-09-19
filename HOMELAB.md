# Homelab fork notes (zerotoidea)

This is Raja’s fork of [we-promise/sure](https://github.com/we-promise/sure) (AGPLv3).

**Live instance today:** Proxmox CT **104** — still runs `ghcr.io/we-promise/sure:stable` plus host mounts under `/opt/sure/overrides/` (Ollama tool fixes). Do **not** point production at this fork until a tagged custom image is built and smoke-tested.

## Goals
1. Improve assistant tool use for local Ollama (biggest/smallest, month totals) in-repo instead of fragile host overrides alone.
2. Build and publish our own image: `ghcr.io/rajakrishna/sure:<tag>`.
3. Cut CT 104 over to that image; keep Postgres/Redis volumes untouched.

## Shipped in this fork (in-repo, no host mounts required)

### Assistant / Ollama
- `get_transactions` accepts `month` (`YYYY-MM` or `MMM-YYYY`) and maps it to start/end dates (honors a custom family month-start day).
- System prompt + session reminder: biggest / largest / top / max / smallest / min questions **must** call `get_transactions` with `sort_by: amount`, `order` desc|asc, `page_size` 5, `month` or dates, and `types` expense|income. Answer **#1 only** (merchant, amount, date, account). Never narrate an unsorted page row. Keep answers short with real dollar figures.
- OpenAI-compatible Ollama hosts (`:11434` or hostname containing `ollama`): `tool_choice: required` when tools are present (still `none` on the final responder round). Qwen models also send `think: false`.

### Chat composer (was “Coming soon”)
- **+** add account / transaction / goal context, or attach a file
- **/** slash commands (`/biggest`, `/smallest`, `/income`, `/budget`, `/networth`, `/goals` when preview is on)
- **@** mention picker (same catalog)
- Click-pointer adds the current page’s account, transaction, or goal when the URL matches
- Selected context is prepended to the user message so local models see names and amounts

### Preview / Goals
- `get_goals` + `create_goal` are preview-gated (Settings → Preferences) and available on MCP for opted-in users
- Goal show menu: **Ask in chat** seeds the composer with that goal
- `GET /holdings/new` redirects to the trade form instead of a “Coming soon” stub

## Deploy plan (when ready)
1. CI: GitHub Actions → build Dockerfile → push `ghcr.io/rajakrishna/sure:stable` (and git sha tags). Repo must allow GHCR packages for this account.
2. On CT 104: snapshot DB (or Sure backup), change `compose.yml` web+worker `image:` to our GHCR image, `docker compose pull && up -d`.
3. Smoke: login, MCP, chat “biggest expense in August”, Sidekiq worker healthy, + / @ / file attach on the chat form, Goals via Plan (preview on).
4. After cutover, remove `/opt/sure/overrides/` mounts (`zz_get_transactions_month_compat.rb`, `zz_ollama_chat_tools.rb`, `zz_ollama_think_false.rb`) — that logic now lives in the app.
5. Keep `upstream` remote to `we-promise/sure` and rebase/merge periodically (AGPL + security).

## Public URL
https://sure.zerotoidea.com (TinyAuth / gateway — see homelab-docs inventory).
