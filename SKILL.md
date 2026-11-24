---
name: retool-setup
description: Build a new Retool app with the Retool CLI or Retool's MCP server. Use when the user wants to build an internal tool, admin panel or dashboard with Retool, or connect their agent to Retool.
license: MIT
allowed-tools: Bash, WebFetch
compatibility: The CLI path needs bash, Node.js 22+, git and pnpm. The MCP path needs an MCP client connected to https://mcp.retool.com/mcp with the mcp:read and mcp:write scopes.
metadata:
  author: retool
  version: 0.6.0
---

# Build a Retool app

> Read this file in full. If a fetch tool summarized it, re-fetch it with `curl -fsSL <this URL>`.

There are two ways to build a Retool app:

- **The CLI:** you write the React app code locally, and Retool validates and hosts it. This uses no Retool AI credits.
- **The MCP:** you describe the app, and Retool's app builder writes the code in the user's organization. This uses Retool AI credits.

## 1. Confirm the plan

Send this and wait for a yes. Leave out any question the user already answered:

```
Here's what I'll do to build this in Retool.

1. Connect to your Retool organization.
2. Create the app you described.
3. Check it and give you a private preview link.
4. Ask before publishing it to your team.

To get started, tell me:
- What the app should do, and what data it uses (sample data is fine).
- Your Retool URL, like https://<your-org>.retool.com. If you're not sure, I'll find it.

Shall I proceed?
```

If no data source is named, use seed data inside the app.

## 2. Choose a path

| Situation | Path |
| --- | --- |
| The user asked for the CLI or the MCP | Use what they asked for |
| You have a bash tool | **CLI** (A) |
| No bash tool, but `retool_*` MCP tools are connected | **MCP** (B) |
| Neither | Give the user the MCP setup in B1, then stop |

If the CLI path gets stuck at sign-in and `retool_*` tools are connected, offer the MCP path, mention that it uses Retool AI credits, and switch only if the user says yes.

## A. CLI path

### A1. Find the Retool URL (host URL)

This is the origin of the user's organization: `https://<your-org>.retool.com`, a Space URL, or a self-hosted domain. Stop at the first match:

1. The user gave one. Keep only `https://` plus the hostname.
2. `retool auth status --json` lists a signed-in host. If there are several, ask which one. It exits `1` when there are none; that's expected.
3. `$RETOOL_HOST` is set.
4. A Retool MCP is connected: use `retoolOrigin` from its login-status tool, and tell the user which organization you'll use.
5. Ask once. Users without Retool can sign up free at https://retool.com.

Never invent a host. If the user's URL conflicts with one you found, use the user's.

### A2. Install and read the spec

**Retool plugin sandbox** (Claude app or ChatGPT Work): if `find ~/.claude ~/.config ~/.local -name bootstrap-retool.sh -print -quit 2>/dev/null` prints a path, don't install anything. Run `sh <that path> "$(pwd -P)" "<host URL>"` and start every later shell call with `export PATH="$HOME/.retool/bin:$PATH"`.

**Everywhere else**, start every shell call with the first line below:

```bash
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"; export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"
pnpm -v || { COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack enable pnpm && pnpm -v; }
retool --version || { mkdir -p "$PNPM_HOME/bin" && pnpm i -g @tryretool/cli && retool --version; }
RETOOL_HOST="<host URL>" retool skill show retool-ready > /tmp/retool-ready.md
```

Read `/tmp/retool-ready.md` in full before writing any code. It needs no sign-in. If `show` is unknown, run `retool update` and retry.

### A3. Sign in

Stop at the first step that works:

1. `retool auth status --json` shows the host: you're signed in.
2. `RETOOL_TOKEN` is set: run `retool auth login --token "$RETOOL_TOKEN" --host "<host URL>"`.
3. The user has a terminal on this same machine: ask them to run `retool auth login --host <host URL>` and click **Authorize**.
4. Remote sandbox: run `retool auth login --device --no-wait --json --host "<host URL>"` and show the user the URL and code. After they approve, run it again with `--resume --wait 30` instead of `--no-wait`. Exit `2` means pending: wait the returned `interval`, then resume.
5. Device sign-in is disabled: ask for a Personal Access Token (**Settings → Retool API → Access Tokens**, scope `react_apps:write`), set as `RETOOL_TOKEN` or pasted. Use it only to sign in, and never repeat it. Or offer the MCP path (see step 2).

### A4. Create, build, preview

If `.retool/app.json` exists, this is already an app: run `retool pull` and skip the `init` step below. `apps init` refuses to run inside a git repo. If `git rev-parse --is-inside-work-tree` succeeds, create the app under `$HOME/retool-apps/` and tell the user where it is.

```bash
retool apps init <app-dir> --name "<App Name>" --json \
  --analytics '{"entryAgent":"<claude_code|codex|cursor|unknown>","buildType":"new_app"}'
cd <app-dir> && pnpm install          # pnpm only, never npm
```

Leave out `--analytics` in a plugin sandbox, and don't edit `.retool/`.

For a named resource, read `backend/resources/` (refresh it with `retool resource types`).

1. Write the app following `/tmp/retool-ready.md`.
2. Run `retool check --json` after each change until it passes.
3. Run `retool push --wait -m "<change>" --json` and give the user the preview URL.

### A5. Publish (ask first)

Run `retool publish --identifier <slug> --json`. Add `--approve-functions` only if the user says yes to approving them.

## B. MCP path

### B1. Connect

If `retool_*` tools exist, call `retool_list_writable_app_folders`. If it succeeds, you're connected. The organization was chosen at sign-in, so you don't need a Retool URL. If a login-status tool exists, tell the user which organization you're building in.

If there are no `retool_*` tools, give the user these steps, then stop. They restart their session afterward.

- **Claude Code:** run `claude mcp add --transport http retool https://mcp.retool.com/mcp`, start a new session, then `/mcp` → `retool` → sign in.
- **Claude app:** **Customize → Connectors** → **Retool**, using `https://mcp.retool.com/mcp`.
- **ChatGPT:** **Settings → Plugins → Add MCP server**, type **Streamable HTTP**, the same URL, then **Authenticate**.
- **Other clients:** add an HTTP MCP server named `retool` at that URL and run the client's MCP sign-in.
- **Self-hosted** (4.0.0 or later): use `https://<your-retool-domain>/mcp`.

At sign-in, the user enters their organization URL and allows **mcp:read** and **mcp:write**. Full steps: https://docs.retool.com/build/apps/guides/create/mcp

### B2. Create and follow the build

1. **Data:** if a resource is named, find it with `retool_list_resources`. To check a table's shape, call `retool_get_resource_ts_definitions`, then `retool_execute_resource_ts` with a read-only snippet.
2. **Create:** call `retool_create_or_append_react_app_thread_message` with no `appUuid`. Use the personal folder from B1 if there is one. Write one complete prompt covering:
   - the app's job,
   - the exact resource and table names, or seed data,
   - the screens, fields and actions,
   - any rules,
   - "Don't publish."

   Save the returned `appUuid` and `generationId`.
3. **Follow:** call `retool_tail_react_app_thread_stream` until it completes. If it times out, call it again. If it needs review, get the request with `retool_list_pending_react_app_thread_reviews`, show it to the user, and reply with `retool_respond_to_react_app_thread_review`.
4. **Verify:** read the app's main files with `retool_list_react_app_files` and `retool_read_react_app_files` to confirm every feature. Send fixes to the **same** thread with the `appUuid`. Then give the user the `app_url` from `retool_get_app`, and say the app is private and unpublished.

### B3. Publish (ask first)

Call `retool_publish_react_app` with an identifier the user chooses. If functions block publishing, list them with `retool_list_pending_react_app_function_approvals`; the user approves them in the Retool editor.

## Rules for both paths

- Ask before publishing, before approving functions, and before any write to the user's data.
- Never collect passwords or database credentials. Resource creation returns a URL where the user enters credentials themselves.
- When you're blocked, tell the user what's done, what's blocking, and the one thing you need, then wait. Don't:
  - build a non-Retool stand-in,
  - hand-write Retool scaffolding,
  - create duplicate apps,
  - switch organizations, or
  - schedule retries.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `retool: command not found` or `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` | Add the PATH prefix from A2 to that shell call. |
| `OAuth device authorization is not enabled` | Ask for a token (A3 step 5), or offer the MCP. |
| `check` reports `typecheck: skipped` | Run `pnpm install` in the app directory. |
| CLI exit code 3 | The CLI self-updated. Re-run the same command. |
| MCP `429` or "agent start failed" | The app may already exist. Check `retool_list_apps` and `retool_list_react_app_threads`, and continue that thread. Retry once, then stop and report it. |
| A Retool MCP tool is missing or denied | Reconnect the MCP and allow `mcp:read` and `mcp:write`. |

Docs: [CLI reference](https://docs.retool.com/build/apps/reference/cli) · [MCP tools](https://docs.retool.com/org-users/reference/mcp-tools)
