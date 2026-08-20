---
name: retool-ready
description: 'Use when writing, editing, scaffolding, debugging, or publishing a code-based Retool app: a React/TypeScript project stored in local files and managed with the `retool` CLI (`init`, `check`, `push`, `publish`). Covers new apps, migrations from an existing Vite/React project, serverless functions, resources, and `retool check` failures. Load this even when Retool MCP tools (`retool_*`) are connected; run `retool skill show retool-ready` to pick between the CLI and MCP. Skip for the Retool GUI, workflows, pricing, cloud-vs-on-prem questions, or changes to the CLI source.'
---

# Retool Ready

The shape spec for Retool app code is not in this file. Print it and read it in
full before you write or edit any app code:

```bash
retool skill show retool-ready
```

That prints the spec compiled into the CLI core you are running, and it is that
same core's `retool check` that decides whether your code is valid.

This file holds no part of the spec on purpose. A copy on disk is pinned to
whichever version wrote it while the core keeps updating itself, so a copy can
tell you to write code the running validator rejects.

## If `retool` is not on PATH

Set the CLI up first, then run the command above. In a process-isolated agent
sandbox, the `retool-cli` skill covers persistent storage, bootstrap, Retool host
selection, and authentication. Claude Cowork is one example of a harness that
may need that flow.

If the CLI reports that no host is selected, supply the full HTTP(S) origin, not
a bare subdomain. Retool Cloud commonly uses `https://<org>.retool.com` for an
organization. Some customers have Retool Spaces enabled; only in that case, a
Space may use `https://<space>.<org>.retool.com`. Those are examples, not
URL-construction rules: use the exact configured origin for a custom domain or
subdomain, internal environment, or self-hosted instance, and never derive a
Space URL from its display name.

## If `skill show` fails

`error: unknown command 'show'` means the cached core predates the command. Run
`retool update`, then run `retool skill show retool-ready` again; a new core takes
effect on the next run.

If it still fails, the selected host pins a core too old to print its own spec.
Stop and tell the user their Retool organization, Space, or instance needs
upgrading. Do not write app code from memory instead, and do not go hunting for
another copy of the spec: any copy you find belongs to a different core than the
one that will validate your code, which is the problem this command exists to
avoid.
