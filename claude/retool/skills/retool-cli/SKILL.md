---
name: retool-cli
description: Make the `retool` CLI runnable in a process-isolated sandbox, select the exact Retool host URL, preserve login across sandbox sessions, then use it to build, check, push, and publish Retool apps. Use when the user wants to create, edit, or publish a code-based Retool app; when `retool` reports `command not found`; or when Retool auth is missing in a new sandbox session. Covers persistent bootstrap, custom and self-hosted URLs, optional Retool Spaces, credential reuse, and signing in without a browser.
---

# Running the `retool` CLI

The CLI ships inside this plugin. There is nothing for you to install: no
`npm install`, no package manager, no download step of your own. Don't try one.
The npm registry is often unreachable from an agent sandbox, and it isn't where
this CLI comes from anyway.

What ships here is the launcher (`scripts/retool-launcher.cjs`) and a bootstrap
script (`scripts/bootstrap-retool.sh`). The bootstrap installs an ephemeral
`retool` shim for this session. The shim points credentials and the downloaded
CLI core at a persistent workspace, where they survive the sandbox's ephemeral
processes and local filesystem.
The plugin builder injects the generated launcher beside the bootstrap when it
assembles the distributable artifact; the launcher is intentionally not checked
into the plugin sources.

## 1. Choose persistent storage before signing in

In a process-isolated sandbox, use a connected or mounted persistent workspace
that exists before login and is usually the current directory. Claude Cowork is
one example of a harness with this shape. Do not use `/tmp`, an ephemeral home
directory, or the plugin directory; those can disappear with the session.

```bash
workspace_root="$(pwd -P)"
retool_host_url="https://retool.example"
sh "<this skill's directory>/scripts/bootstrap-retool.sh" "$workspace_root" "$retool_host_url"
export PATH="$HOME/.retool/bin:$PATH"
```

Replace the example with the Retool **host URL**: the full HTTP(S) origin
(`scheme://hostname[:port]`), not an organization name, Space name, or bare
subdomain. Common Retool Cloud forms are `https://<org>.retool.com` for an
organization and, when Spaces is enabled, `https://<space>.<org>.retool.com` for
a Space. These are examples, not URL-construction rules. A custom domain or
subdomain, internal environment, or self-hosted instance can use a different
hostname; always use its exact configured origin. The CLI calls this value a
host in `--host` and `RETOOL_HOST`.

Some customers have Retool Spaces enabled. Do not assume Spaces is enabled or
call an ordinary organization a Space. When the user identifies a Space, use
that Space's exact URL rather than the parent organization's URL, and do not
derive it from the Space's display name.

`<this skill's directory>` is the directory you loaded this `SKILL.md` from. If
you don't have that path, find the bootstrap script:

```bash
find ~/.claude ~/.config ~/.local -name bootstrap-retool.sh -print -quit 2>/dev/null
```

The bootstrap creates these persistent paths:

- `<workspace>/.retool/credentials.json`: access and refresh tokens, written
  only after login.
- `<workspace>/.retool/default-host.json`: the selected Retool host URL, with no
  secret.
- `<workspace>/.retool/cli`: the verified CLI core cache.

Retool app checkouts already use `.retool/app.json`, and the CLI excludes the
whole `.retool/` directory from app source and Git commits. Bootstrap adds
`.retool/` to the session's global Git excludes before a repository exists, so
credentials stay ignored if Git is initialized later. In an existing
repository, it also writes the repository's private `.git/info/exclude`. It
refuses a workspace nested inside another repository; rerun it from that
repository's root. The shim sets `NODE_USE_ENV_PROXY=1`, `RETOOL_HOST`,
`RETOOL_CREDENTIALS_PATH`, and `RETOOL_CLI_STATE_DIR`. The host URL makes the
first command install the core served by that Retool organization or instance,
even before a login exists. Do not export these values separately.

The bootstrap host URL binds this sandbox session to one Retool organization,
instance, or—when Spaces is enabled—Space. To point the session somewhere else,
rerun bootstrap with that target's URL. To remove the binding and let the CLI use
the default recorded by `retool auth use`, rerun bootstrap with only the
workspace argument. A `RETOOL_HOST` supplied directly to a command still
overrides the bootstrap value.

Outside an app checkout, the CLI resolves an explicit `--host`, then
`RETOOL_HOST`, then the default set by `retool auth use <host-url>`. Inside a
checkout, the host URL in `.retool/app.json` keeps app-scoped commands on the
organization or Space that owns the app. For customers using Spaces, each Space
has its own stored session and core-version pin; do not reuse an app or resource
merely because a sibling Space has the same display name.

Scaffold the app in that same persistent workspace, so unpushed work survives
the session too. One thing can force you off it: a mounted workspace can refuse
to delete files. `retool check` rewrites the generated hooks on every run, so on
an older core that refusal becomes an `EPERM` and `check` can't finish.

Check for it before you scaffold, so you never have to migrate a checkout:

```bash
probe="$(pwd -P)/.retool-delete-probe"
touch "$probe" && rm "$probe" 2>/dev/null && echo "workspace is fine" || echo "scaffold on local disk"
```

On `scaffold on local disk`, run `retool init --dir "$HOME/app"` and build there.
Leave the bootstrap pointed at the persistent workspace, so the login and core
cache still persist. Only the checkout moves, and it dies with the session, so
push before the session ends.

If you only hit the `EPERM` after scaffolding, **do not run `retool init` again.**
It refuses to run inside a checkout, and from outside one it scaffolds a brand new
app, which loses your edits and points a later push at the wrong app. Copy the
checkout you already have instead, including the `.retool/app.json` that carries
its identity:

```bash
mkdir -p "$HOME/app/.retool"
tar --exclude=.retool --exclude=node_modules -cf - . | tar -xf - -C "$HOME/app"
cp ./.retool/app.json "$HOME/app/.retool/app.json"
cd "$HOME/app" && pnpm install && retool check
```

Copy the whole checkout, not a list of paths. An app has files a list would miss:
config at the root, assets, anything you added yourself. Dropping one silently
means the next `push` sends a partial app.

The two exclusions are deliberate. `node_modules` gets rebuilt by `pnpm install`,
and `.retool/` holds the credentials and the core cache, which belong in the
workspace. Only `app.json` comes across, because it carries the app identity a
later `push` needs.

If the app was already pushed, `retool clone <app> --dir "$HOME/app"` is the
cleaner route, since it rebuilds the checkout and its identity from the server.

## 2. Reuse auth before asking the user to log in

Assume every shell call is fresh, so export only the shim's PATH at the start of
each call:

```bash
export PATH="$HOME/.retool/bin:$PATH"
retool_host_url="https://retool.example"
retool auth status --host "$retool_host_url"
```

If the requested host is already signed in, continue without logging in. A new
isolated sandbox session does not by itself mean the credential is missing.

If status says the host has no stored session, use a Personal Access Token with
the **Retool React apps → CLI write** scope (`react_apps:write`):

```bash
export PATH="$HOME/.retool/bin:$PATH"
retool_host_url="https://retool.example"
RETOOL_TOKEN=<pat> retool auth login --host "$retool_host_url"
retool auth status --host "$retool_host_url"
```

Ask the user to create the token under Retool Settings → Retool API → Access
Tokens. Run login only after bootstrap so it writes to the persistent workspace.
`auth status` is enough verification; do not provision a throwaway app.

Which login flow to use depends on your harness:

- **Each shell invocation is a separate process, and you can't show its output
  until it exits** (a common process-isolated agent-sandbox constraint): run
  `retool auth login --device --no-wait --json --host "https://retool.example"`,
  show the returned URL/code to the user, then collect approval in a later
  process with
  `retool auth login --device --resume --wait 30 --json --host "https://retool.example"`.
  `authorized` exits 0. `pending` exits 2 and includes an `interval` in seconds;
  sleep that long before resuming again. `denied`, `expired`, and `failed` exit 1:
  start a fresh no-wait flow after `expired`, but stop and surface the error after
  `failed` rather than retrying the same broken flow. Use the PAT flow above
  instead when a human cannot approve OAuth.
- **You share a live terminal with the user**: plain `retool auth login` (browser
  OAuth) or `retool auth login --device` (prints a short code and a URL to
  approve on any machine) both work, and give an auto-refreshing session instead
  of a static token.

The credential file contains a live secret and has mode `0600`. The bootstrap
makes `.retool/` private with mode `0700`. Use a dedicated, private persistent
workspace. Do not put it in a shared or cloud-synced folder.

## 3. Verify the CLI

After auth selects the host, prove the launcher and core cache in one call:

```bash
export PATH="$HOME/.retool/bin:$PATH"
retool --version
```

Report the printed version without re-running the check.

## 4. Read the app shape spec before writing any code

Run this and read the output in full:

```bash
export PATH="$HOME/.retool/bin:$PATH"
retool skill show retool-ready
```

That prints `retool-ready`, the shape spec for Retool app code: file layout, the
`use<Fn>` hook pattern for data, resource rules, and how to read `retool check`
failures. Don't write app code from memory when it's one command away.

The spec itself is not bundled in this plugin on purpose. It has to match the CLI
core that validates against it, and the core updates itself, so the only copy that
is guaranteed correct is the one the running core prints. The `retool-ready` skill
that ships beside this one is a pointer to the same command, so loading it is no
substitute for running it.

If that command fails with `error: unknown command 'show'`, the cached core in
this workspace predates it. Update, then retry, since a new core takes effect on
the next run:

```bash
export PATH="$HOME/.retool/bin:$PATH"
retool update && retool skill show retool-ready
```

If it still fails after updating, the selected host pins a core too old to print
its own spec. Stop and tell the user their Retool organization, Space, or
instance needs upgrading. Don't write app code from memory instead, and don't go
looking for a copy of the spec elsewhere: any copy you find belongs to a
different core than the one that will validate your code, which is the whole
problem this command exists to avoid.

The short version of the loop: `retool init` to scaffold, `pnpm install` from
the checkout root once so the local typecheck can run, `retool check` after each
change, `retool push -m "<what changed>"`, `retool publish --identifier <slug>`.

Install with pnpm, never npm. A checkout is a pnpm workspace, and npm ignores
`pnpm-workspace.yaml`, so an npm tree can pass the local typecheck and still be
thrown away at preview and publish.

## Troubleshooting

| Symptom                                          | Cause and fix                                                                                                                     |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `retool: command not found`                      | This shell never got the PATH export. Re-run the step 2 block in this call.                                                       |
| The first run hangs or fails fetching the core   | Rerun bootstrap with the full Retool host URL. If it still fails, ask the user to allow that host on egress.                      |
| `No host: pass --host <url> or set $RETOOL_HOST` | Rerun bootstrap with the workspace and full Retool host URL, then retry the command.                                              |
| A new session says there is no stored login      | Bootstrap from the same persistent workspace as before, then run `auth status` again. Do not log in until that check fails.       |
| The bootstrap names the wrong workspace or host  | Rerun `bootstrap-retool.sh` with the correct persistent workspace and host URL. It changes the target but does not move secrets.  |
| An existing login expired                        | Browser/device sessions refresh automatically. For a PAT, ask the user for a replacement only when Retool rejects the stored one. |
| `git: command not found` from `clone` or `push`  | Those two shell out to `git`. Nothing in this plugin can substitute for it; tell the user the environment needs `git`.            |
| `check` reports `typecheck: skipped` and exits 1 | The checkout has no TypeScript yet. Run `pnpm install` from the checkout root, then `retool check` again.                         |
| `ERR_PNPM_FETCH_401` on an org package           | The org package credential went stale. Run `retool pull`, then retry the install.                                                 |
| `EPERM` generating hooks, in a mounted workspace | That mount won't let an older core delete the generated hooks. Move the checkout to local disk as shown in step 1.                |
| Exit code 3                                      | The selected host required a newer CLI, the core self-updated, and your command didn't run. Re-run the same command as-is.        |
| `unknown command 'show'` from `skill show`       | This workspace's cached core predates the command. Run `retool update` and retry, as step 4 describes.                            |

Never fall back to `npm install -g @tryretool/cli`, and never conclude the CLI is
unavailable because a command wasn't found. The launcher is on disk in this
plugin; a failure is a PATH, proxy, or egress problem, and the table above covers
each one.
