# Retool for Claude Code

Build, check, push, and publish code-based Retool apps from Claude Code, and work
with your Retool organization through Retool's MCP server.

## Setup

Claude asks for your Retool base URL when you enable the plugin. Give the full
origin with the scheme and no trailing slash, for example
`https://acme.retool.com`. Self-hosted instances and custom domains use their
own configured origin.

The plugin builds the MCP server URL from that value. One artifact works for
Retool Cloud and for self-hosted organizations.

## What you get

| Component            | Purpose                                                                                     |
| :------------------- | :------------------------------------------------------------------------------------------ |
| `retool` MCP server  | Apps, resources, workflows, users, and agent threads in your Retool organization.           |
| `retool-ready` skill | Points Claude at the app-code spec printed by `retool skill show retool-ready`.             |
| `retool-cli` skill   | Makes the `retool` CLI runnable in a sandbox session, and keeps your login across sessions. |

The plugin registers **no hooks**. Nothing runs on your prompts, on your tool
calls, or at session start.

## Network activity

The plugin reaches three hosts.

### 1. Your Retool organization

Everything the plugin does with your apps and data goes to a Retool host you
control. That covers the MCP server at `/mcp`, and every `retool` CLI command:

- Signing in, over the OAuth device flow at `/api/oauth2/device_authorization`
  and `/api/oauth2/token`.
- Reading and writing apps and resources, at `/api/apps`, `/api/resources`, and
  `/api/pages/uuids/`.
- `push`, `pull`, `clone`, and `publish`, which use the git transport and the app
  APIs under `/api/ai/rr/git/v2/apps/`.
- Your organization's own library packages, through the package registry at
  `/api/ai/rr/npm/`.
- The CLI core manifest at `/api/cli/manifest`.
- One analytics event from `retool check` in a linked checkout, at
  `/api/cli/check-event`.

This endpoint list is illustrative, not a contract. New CLI features add
endpoints.

**Which Retool host.** Usually the URL you configured when you enabled the
plugin. Inside an app checkout it is the host recorded in that checkout's
`.retool/app.json`, which is the organization, instance, or Space that owns the
app. Those differ if you work on an app from somewhere other than the URL you
configured, and `--host` or `RETOOL_HOST` overrides both. Either way it is a
Retool host you have signed in to, never a third party.

### 2. `registry.npmjs.org`, for public packages

A Retool app checkout is a pnpm workspace, so `pnpm install` downloads its public
dependencies from the public npm registry. The CLI writes a `.npmrc` at the
checkout root that pins public packages to `https://registry.npmjs.org/` on
purpose, and routes only your organization's own scope to Retool. This is
ordinary package installation, and it is the largest share of the plugin's
requests by count.

### 3. `cli.retool-edge.com`, for the CLI core only

The plugin ships a small launcher, not the CLI itself. The first `retool` command
downloads a signed core of about 8 MB, verifies its signature, and caches it in
`<workspace>/.retool/cli`.

The launcher takes that core from your own Retool host at `/api/cli/manifest`
when a host is selected. Only when no host is selected does it fall back to
Retool's CDN at `https://cli.retool-edge.com`. That fetch carries no credentials.
It sends an `X-Retool-CLI-Version` header, which is how Retool identifies CLI
traffic in an access log.

### Turning analytics off

`retool check` inside a checkout linked to a Retool app sends a single bounded
event to that checkout's Retool host. No other command sends one. Either switch
turns every analytics header and request off:

```bash
export RETOOL_CLI_TELEMETRY=0
export DO_NOT_TRACK=1
```

## How the event is labelled

The event carries one label naming which agent ran the command, and nothing else
about the session.

This plugin's bootstrap script sets that label itself. It exports
`RETOOL_CLI_AGENT=claude_cowork`, so a session started through the `retool-cli`
skill reports as Cowork rather than being guessed at. The export defers to a value
already in the environment, so setting `RETOOL_CLI_AGENT` yourself wins.

Without that variable the CLI infers the label from the environment, reading
`CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`, `CODEX_HOME`, `CODEX_SANDBOX`, and
`CURSOR_TRACE_ID`.

Either way the recorded value comes from a fixed list, and it carries no prompt
text, no model name, no file contents, and no session content.

## Credentials and files

`retool auth login` writes tokens to `<workspace>/.retool/credentials.json` with
mode `0600`, inside a `.retool/` directory with mode `0700`. Use a private
workspace. Do not put it in a shared or cloud-synced folder.

The `retool-cli` skill runs a bootstrap script. That script adds `.retool/` to
your global git excludes file, and, when the workspace is a git repository, to
that repository's `.git/info/exclude`. This keeps credentials out of a commit
even if you run `git init` later.

The bootstrap also writes a `retool` shim to `~/.retool/bin`. The shim
disappears with the session. Your login and the verified core stay in the
workspace.

## Support

- Documentation: https://docs.retool.com
- Support: https://docs.retool.com/support
- Privacy policy: https://docs.retool.com/legal/privacy-policy
