---
name: retool-setup
description: Build a new Retool app with the Retool CLI. Use when the user wants to build an internal tool, admin panel or dashboard with Retool, or set up the Retool CLI.
license: MIT
allowed-tools: Bash, WebFetch
compatibility: Requires bash, Node.js 22+, git and pnpm.
metadata:
  author: retool
  version: 0.4.0
---

# Set up Retool

> Read this file in full. If a fetch tool summarized it, re-fetch it with `curl -fsSL <this URL>`.

## 1. Confirm the plan

Send this and wait for a yes. Leave out any question the user already answered:

```
Here's what I'll do to get you building on Retool.

1. Get the Retool CLI ready in this environment.
2. Sign you in to your Retool organization.
3. Create a new Retool app and build what you described.
4. Validate it and give you a private preview link. I'll ask before publishing it to your team.

To get started, tell me:
- What the app should do, and what data it uses (sample data is fine).
- Your Retool URL: the address you use for Retool in your browser, like https://<your-org>.retool.com. If you're not sure, I'll find it.

Shall I proceed?
```

If no data source is named, use seed data inside the app.

## 2. Find the Retool URL (host URL)

It's the origin of the user's Retool organization, such as `https://<your-org>.retool.com`, a Space URL, or a self-hosted domain. Stop at the first match:

1. The user gave one. Keep only `https://` plus the hostname.
2. `retool auth status --json` lists a signed-in host. If there are several, ask which one. It exits `1` when there are none; that's expected.
3. `$RETOOL_HOST` is set.
4. A Retool MCP server is connected: call its login-status tool and use `retoolOrigin`. Tell the user which organization you'll use.
5. Ask once. If they don't use Retool yet, they can sign up free at https://retool.com.

Never invent a host. If the user's URL conflicts with what you found, use the user's.

## 3. Install the CLI

**Retool plugin sandbox** (Claude app or ChatGPT Work): if `find ~/.claude ~/.config ~/.local -name bootstrap-retool.sh -print -quit 2>/dev/null` prints a path, don't install anything. Run `sh <that path> "$(pwd -P)" "<host URL>"` and start every later shell call with `export PATH="$HOME/.retool/bin:$PATH"`.

**Everywhere else**, start every shell call with the pnpm prefix in the first line below:

```bash
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"; export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"
pnpm -v || { COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack enable pnpm && pnpm -v; }
retool --version || { mkdir -p "$PNPM_HOME/bin" && pnpm i -g @tryretool/cli && retool --version; }
```

Then read the build spec in full before writing any code. It needs no sign-in:

```bash
RETOOL_HOST="<host URL>" retool skill show retool-ready > /tmp/retool-ready.md
```

If it fails with `unknown command 'show'`, run `retool update` and retry. Build with the CLI even where the spec mentions MCP tools.

## 4. Sign in

Stop at the first step that works:

1. `retool auth status --json` shows the host: you're signed in.
2. `RETOOL_TOKEN` is set: `retool auth login --token "$RETOOL_TOKEN" --host "<host URL>"`.
3. The user has a terminal on this same machine: ask them to run `retool auth login --host <host URL>` and click **Authorize**.
4. Otherwise (remote sandbox): run `retool auth login --device --no-wait --json --host "<host URL>"` and show the user the URL and code. After they approve, run the same command with `--resume --wait 30` instead of `--no-wait`. Exit `2` means pending: wait the returned `interval`, then resume.
5. If device sign-in isn't enabled, send this and wait:
   > I need a Personal Access Token. In Retool, go to **Settings → Retool API → Access Tokens**, create one with the `react_apps:write` scope, and set it as `RETOOL_TOKEN` in this environment or paste it here. I'll use it only to sign in.

   Log in with the token, and never repeat it.

Never ask for a password.

## 5. Create the app

If `.retool/app.json` exists, this is already an app: run `retool pull` and skip to step 6.

`apps init` refuses to run inside a git repo. If `git rev-parse --is-inside-work-tree` succeeds, create the app under `$HOME/retool-apps/` and tell the user where it is.

```bash
retool apps init <app-dir> --name "<App Name>" --json \
  --analytics '{"entryAgent":"<claude_code|codex|cursor|unknown>","buildType":"new_app"}'
cd <app-dir> && pnpm install
```

Use pnpm, never npm. Leave out `--analytics` in a plugin sandbox. Don't edit `.retool/`.

For a named resource or table, read `backend/resources/` (refresh it with `retool resource types`). If the table doesn't exist, tell the user and offer seed data. Never collect database credentials.

## 6. Build, preview, publish

1. Write the app following `/tmp/retool-ready.md`.
2. Run `retool check --json` after each change until it passes. Use `retool check --fix` only for Retool-owned files.
3. Run `retool push --wait -m "<change>" --json` and give the user the preview URL. Tell them about any functions that need approval.
4. **Ask before publishing.** Then run `retool publish --identifier <slug> --json`. Approve functions (`--approve-functions`) only with the user's yes.

## When you're blocked

Stop and tell the user what's done, what's blocking, and the one thing you need. Don't:

- create apps with Retool MCP tools,
- build a non-Retool stand-in app,
- hand-write Retool scaffolding,
- use a different organization,
- schedule retries, or
- ask the user to run commands in a sandbox they can't reach.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `retool: command not found` or `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` | Add the PATH prefix from step 3 to that shell call. |
| `OAuth device authorization is not enabled` | Ask for a token (step 4.5). |
| `check` reports `typecheck: skipped` | Run `pnpm install` in the app directory. |
| Exit code 3 | The CLI self-updated. Re-run the same command. |
| Anything else | Re-run with `--debug`. |

Docs: https://docs.retool.com/build/apps/reference/cli
