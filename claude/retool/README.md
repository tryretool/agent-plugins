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

The plugin talks to two hosts. Nothing else.

### Your own Retool host

Everything the plugin does for you goes to the Retool URL you configured. That
covers the MCP server at `/mcp`, and every `retool` CLI command:

- Signing in, over the OAuth device flow at `/api/oauth2/device_authorization`
  and `/api/oauth2/token`.
- Reading and writing apps and resources, at `/api/apps`, `/api/resources`, and
  `/api/pages/uuids/`.
- `push`, `pull`, `clone`, and `publish`, which use the git transport and the app
  APIs under `/api/ai/rr/git/v2/apps/`.
- `pnpm install` inside a checkout, which resolves org packages through the
  package proxy at `/api/ai/rr/npm/`.
- The CLI core manifest at `/api/cli/manifest`.
- One analytics event from `retool check` in a linked checkout, at
  `/api/cli/check-event`.

This list is illustrative, not a contract. New CLI features add endpoints. The
guarantee is the host: your own Retool organization or instance, reached at the
URL you configured.

### Retool's CDN, for the CLI core only

The plugin ships a small launcher, not the CLI itself. The first `retool` command
downloads a signed core of about 8 MB, verifies its signature, and caches it in
`<workspace>/.retool/cli`.

The launcher takes that core from your own Retool host at `/api/cli/manifest`
when a host is selected. Only when no host is selected does it fall back to
Retool's CDN at `https://cli.retool-edge.com`. That is the one request that can
reach a host other than your own. It carries no credentials. It sends an
`X-Retool-CLI-Version` header, which is how Retool identifies CLI traffic in an
access log.

### Turning analytics off

`retool check` inside a checkout linked to a Retool app sends a single bounded
event to that same checkout's Retool host. No other command sends one. Either
switch turns every analytics header and request off:

```bash
export RETOOL_CLI_TELEMETRY=0
export DO_NOT_TRACK=1
```

## Data the CLI reads

To label the event above, the CLI checks whether it is running under an agent. It
reads `RETOOL_CLI_AGENT`, `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`, `CODEX_HOME`,
`CODEX_SANDBOX`, and `CURSOR_TRACE_ID`, and it records one value from a fixed
list. It keeps no prompt text and no session content.

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
