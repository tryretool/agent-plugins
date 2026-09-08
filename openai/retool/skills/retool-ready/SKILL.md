---
name: retool-ready
description: 'Use when writing, editing, scaffolding, debugging, or publishing a code-based Retool app: a React/TypeScript project stored in local files and managed with the `retool` CLI (`init`, `check`, `push`, `publish`). Covers new apps, migrations from Vite/React, serverless functions and their generated hooks, governed resources, resource data exploration or setup, and `retool check` failures such as `resourceImports` or parameter destructuring. Load this even when Retool MCP tools (`retool_*`) are connected; this skill owns the app-building surface choice and routes local app resource work through the CLI. Skip for the Retool GUI, workflows, pricing, cloud-vs-on-prem questions, or changes to the CLI source.'
---

# Retool Ready

This is the one shape spec for Retool-native apps. Write code in this shape
and `retool check` is the ground truth that confirms it — when the validator
disagrees with this doc, the validator wins; fix and re-run.

The bet: one shape spec is enough for the model to bridge any vanilla React
app into compliance. There is no per-framework skill.

## Choose one app-building surface

Before you create an app, decide which path you will use

- **CLI:** you write the app files in a local checkout. The user updates the app
  by editing that checkout and running `retool push` again.
- **MCP:** Retool's in-sandbox agent writes the app through a Retool thread. The
  user updates the app by continuing that thread.

When the CLI and MCP are both available with equivalent capabilities, always
use the CLI unless the user directly asks for MCP. App building is one such
task. Do not ask the user to choose when they did not name a surface. Tell the
user that you will use the CLI before you run `retool init` or `retool clone`.

Use one app-creation path at a time. Do not call MCP app-thread tools while you
prepare a CLI checkout. Do not install or use the CLI during an MCP app build.
You can still use MCP-only tools for separate tasks such as access management
that are not covered by the CLI.

Use MCP when the CLI is unavailable. Treat the CLI as unavailable only in these
cases:

- The environment has no shell or filesystem.
- You cannot install the binary.
- You cannot finish `retool auth login`.

Check `--device` and `--token` before you classify the CLI as unavailable. See
"Authenticating the CLI" for those options.

### Keep local resource work on the CLI

Once you select the CLI for an app-building task, use it for the app's resource
work too. This includes discovering resource clients, inspecting schemas or
live data, test-running read-only backend code, creating resources, and making
one-time schema or seed-data changes that the user requested. Read the generated
declarations under `/backend/resources/`, run `retool resource explore`, add
`--allow-mutative` for an authorized immediate write, and use
`retool resource create` when no existing resource fits. `resource explore` is
the local CLI equivalent of the in-sandbox agent's `execute_backend_code`.

Do not call MCP resource tools merely because they are connected, already
authenticated, or can run the same code. MCP authentication does not replace
CLI authentication. For a CLI task, use `retool auth status` and
`retool auth login`; if `resource explore` reports missing resource access, ask
for that access or use another resource instead of switching to MCP. Use MCP
resource tools only when the user directly asks for MCP, the CLI is unavailable,
or the resource task is separate from a local app checkout as mapped below.

### Why the CLI is the default

With the CLI, you edit the files. `retool check` typechecks them locally with no
network round trip. The code that ships is the code you wrote.

The MCP has no file-write tool. The
`retool_create_or_append_react_app_thread_message` tool passes your request to
Retool's in-sandbox agent. That agent writes the code for you.

### Task mappings

Use one surface when both have equivalent capabilities. Use the only supported
surface for tasks that do not overlap:

| Task                                                      | Surface                                                                                                                                                             |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Write, check, push, or publish app code                   | CLI by default: `init`/`clone`, `check`, `push`, `publish`. Use MCP when the user directly asks for it or the CLI is unavailable.                                   |
| Read a file from an app you have not cloned               | MCP: `retool_read_react_app_files`                                                                                                                                  |
| Inspect resources while building from a local checkout    | CLI: read `/backend/resources/`, then use `retool resource explore` for data, schemas, and read-only backend test runs.                                             |
| Make a one-time schema or seed-data change for local work | CLI: `retool resource explore --allow-mutative`. It executes immediately, so use it only when the user requested the side effect.                                   |
| Inspect a resource outside a local app-building task      | MCP: `retool_list_resources` / `retool_execute_resource_ts`                                                                                                         |
| Create a resource                                         | CLI by default: `retool resource create`. Use MCP when the user directly asks for it or the CLI is unavailable. Editing one is MCP-only (`retool_update_resource`). |
| Users, groups, folders, themes, audit logs, workflows     | MCP only                                                                                                                                                            |
| Inspect or steer an existing agent thread                 | MCP: `retool_list_react_app_threads`, the thread stream tools                                                                                                       |

### Publishing and branch ownership

Publish through the surface selected for app creation. Do not switch surfaces
only to publish.

The MCP publish path asks you to review each mutating serverless function with
the user. The CLI's `--approve-functions` flag approves them in a batch. Read
the functions before you pass that flag.

A thread branch has one writer. A local checkout on `retool-agent/<threadId>`
and an MCP thread message both advance the same branch, and `retool push` is a
real git push, so don't drive an R² thread on a branch you have checked out.
Finish or abandon one before starting the other.

## Keep the user informed

Send short summaries of recent activity throughout the build. Each summary
should state what you inspected, changed, learned, or verified. It should also
state what you will do next.

Send another summary when a command reveals useful information, a visible part
works, a check finishes, or the implementation direction changes. If several
tool calls form a long sequence, pause between them to summarize the accumulated
results.

Keep updates useful and brief. Do not narrate every command or file. Do not
repeat a plan without new information. Prefer concrete results, such as "The
table now filters by owner; I am checking empty states next."

When a command blocks progress, state what blocked it and what you are trying
next.

## Choose the Retool host

The CLI calls the full HTTP(S) origin (`scheme://hostname[:port]`) for a Retool
organization or instance a `host`. It is not an organization name, Space name,
or bare subdomain. Common Retool Cloud forms are `https://<org>.retool.com` for
an organization and, when Spaces is enabled,
`https://<space>.<org>.retool.com` for a Space. These are examples, not
URL-construction rules: custom domains or subdomains, internal environments, and
self-hosted instances can use different hostnames. Always use the exact
configured origin in `--host` and `RETOOL_HOST`.

Some customers have Retool Spaces enabled. Do not assume Spaces is enabled or
call an ordinary organization a Space. When the user identifies a Space, use
that Space's exact URL rather than the parent organization's URL, and do not
derive it from the Space's display name. Treat sibling Spaces as isolated
targets even when apps or resources share a name.

Outside a checkout, host-taking commands resolve an explicit `--host`, then
`RETOOL_HOST`, then the default recorded by `retool auth use <host-url>` or a
login. `auth use` selects a host without authenticating, so it can establish the
default before login. Inside a linked checkout, `.retool/app.json` records the
owning host URL and app-scoped commands stay on that organization or Space.

## The build loop

A fresh 0→1 build runs end to end like this:

1. `retool init` creates the server app and scaffolds its linked checkout (a
   backend function, a page, `App.tsx`, a tsconfig, and platform files). It names
   the app from `--name`, an interactive prompt, or the directory name.
   It fetches the server seed first, then writes the local scaffold. This keeps
   the organization theme and server-added packages.
   `--host <host-url>` selects where the app is created; it defaults to
   `$RETOOL_HOST`, then your recorded default. `retool auth status` lists every
   signed-in host and marks that default.
2. `pnpm install` from the root once, so
   `retool check` can typecheck locally. See "Typecheck locally" — this step is
   required, not optional.
3. Replace the scaffold's placeholder function, `backend/example/getGreeting.ts`,
   with your own code as you build. Its hook disappears on the next `check`,
   which regenerates the whole hook directory from `/backend`.
4. Write the backend function(s), then `retool check` to regenerate the hooks.
5. Write the page(s), then `App.tsx` last. `retool check` again.
6. `retool push -m "<what changed>"` records a commit and sends it through the
   gate. Add `--wait` (or run `retool preview --wait`) to get the preview URL.
   Hand that URL to the user and stop — don't try to view the running app
   (see "Do / don't").
7. When the user asks to take the app live, `retool publish --identifier <slug>`
   does that and prints the public URL. See "Publishing".

## Send feedback about the CLI

When app-building work gives you concrete feedback about the Retool CLI, tell
the user what you observed. Offer to share it with Retool. Explain that
`retool feedback` sends the description and the context listed below. Run the
command only if the user agrees:

```
retool feedback -d "<concise feedback>" --json
```

Report positive experiences, confusing or negative experiences, and bugs. Say
which command or action you used, what happened, and what you expected. Report
only what you observed; do not invent feedback or copy private app data into the
description.

The command attaches CLI, launcher, Node.js, platform, architecture, and linked
checkout identifiers. It does not collect logs or file contents. Never include
credentials, access tokens, resource data, or other secrets. Feedback is
best-effort: if authentication is unavailable or submission fails, continue the
user's task and do not retry repeatedly.

## Scaffold outside any existing git repo

`push` and `publish` drive the app's own git history. They find the checkout by
walking up to the nearest `.retool/app.json`, but they run `git` wherever that
checkout sits — so if you `retool init` inside a directory that's already part of
another git repo (a monorepo, say), `push` commits to _that_ repo and pushes its
history. Two things then break:

- The pushed history shares no ancestor with the app's freshly provisioned
  `main`, so `publish` can't merge it: `main (…) is not an ancestor. Merge base
is` empty.
- The `push` auto-commits your app files onto the surrounding repo's current
  branch, changing history you never meant to touch.

So `retool init` refuses to scaffold inside a git repo (or another Retool
checkout). Point it at a standalone directory outside any repo:

```
retool init --dir ~/apps/refunds-dashboard
```

`--force` overrides the check if you really mean to scaffold inside a repo, but
the push behavior above still applies — you'll be pushing that repo's history.

To pick up an app that already exists on the server instead of starting fresh,
run `retool clone <app>` from outside any checkout. It writes a working copy with
its own git rooted on the app's `main` — the base `push` and `publish` expect.

A branch is the line of work; a thread is one chat session on it, and several
threads can share a branch. Agent branches are named `retool-agent/<threadId>`,
so a ref name and a thread id look alike but are not interchangeable.

## Typecheck locally

`retool check` runs four required phases: `hooks`, `validate`, `typecheck`, and
`build`. The typecheck and the production build both need the frontend's
dev dependencies installed in the checkout, and with no compiler it reports
`typecheck: skipped` and `check` exits 1 ("incomplete because a required phase
did not run"). So install once right after `init`:

```
pnpm install
```

New checkouts use a pnpm workspace, so install from the checkout root. For an
older checkout without `pnpm-workspace.yaml`, use the install directory named
by `retool check`.

`init` and `clone` also configure pnpm for your organization's private
`@retool.org.*` packages: the checkout's `.npmrc` routes that one scope to Retool
and everything else to npmjs.org, and the credential lives in your user npm
config, outside the project.

If `pnpm install` fails with `ERR_PNPM_FETCH_401` on a `@retool.org.*` package,
the credential went stale (it is refreshed whenever the CLI talks to the server).
Run `retool pull`, then retry the install. `pnpm install --reporter=ndjson` gives
a machine-readable failure code if you need to detect this.

The local typecheck covers `/frontend` and `/backend`, using the sandbox's own
tsconfig so green locally predicts green on push.

While you're iterating, `retool check --skip-build` runs the other three phases
and reports `build` as intentionally skipped, so it still exits 0 when they pass.
Run the full `retool check` before you push; a skipped build is an
unverified one.

Each directory compiles as its own project, because Retool builds them
separately: Vite bundles the frontend, esbuild bundles each backend function.
Importing across the two is a `TS6059` "not under 'rootDir'" error. To share a
value, duplicate it or move it inside the directory that needs it. To call a
backend function from the frontend, use its generated `use<FunctionName>` hook.

That tsconfig is strict in ways that bite when porting existing code:

- `noUncheckedIndexedAccess`: indexing an array or record gives `T | undefined`.
  Guard it, or assert (`arr[i]!`) when a bounds or modulo check already proves the
  index is valid.
- `noPropertyAccessFromIndexSignature`: index-signature and `dataset` properties
  need bracket access, `el.dataset['title']` rather than `el.dataset.title`.
- `noUnusedLocals` and `noUnusedParameters`: a leftover import or an unused
  callback argument is an error, not a warning.
- `exactOptionalPropertyTypes`: passing `undefined` to an optional property is an
  error unless its type spells out `| undefined`.

## Authenticating the CLI

The commands that reach Retool (`clone`, `push`, `preview`, `publish`, `start`,
`resource explore`, `resource create`) need a stored credential. Run
`retool auth login` once per host. `retool check` is fully local and needs none,
so you can keep checking while signed out.

- Default: after selecting the host, `retool auth login` opens a browser for
  OAuth and stores an auto-refreshing session. Pass `--host <host-url>` when no
  default is recorded.
- Remote or headless shell with a live terminal: `retool auth login --device`
  prints a short code and a verification URL, then polls while you approve it.
- Process-isolated agent sandbox: run
  `retool auth login --device --no-wait --json --host <host-url>`, show the
  URL/code to the user, then run
  `retool auth login --device --resume --wait 30 --host <host-url>` in a later
  shell invocation. For a machine-readable result, add `--json`: `authorized`
  exits 0; `pending` exits 2 and includes an `interval` in seconds, which you
  must sleep before resuming again; `denied`, `expired`, and `failed` exit 1.
  Start a fresh no-wait flow after `expired`; stop and surface the error after
  `failed` instead of retrying the same broken flow. An authorized result means
  the auto-refreshing session was stored for that host.
- Non-interactive CI: create a Personal Access Token under **Settings → Retool
  API → Access Tokens** with **Retool React apps → CLI write**
  (`react_apps:write`). Inject it as `$RETOOL_TOKEN`, then run
  `retool auth login`. This stores the PAT locally without contacting the host;
  the next server command verifies it. PATs do not refresh; rotate or revoke
  them on the same settings page. `--device` and
  `--token` are mutually exclusive. The same PAT supports the full Retool React
  app CLI workflow, including `clone`, `push`, `publish`, and
  `resource explore`.

`retool auth status` lists signed-in hosts and the current default. If a
Retool-bound command fails with an auth error, re-run login for that host before
retrying.

## Native Windows Codex sandbox networking

On native Windows, a pre-upload `UND_ERR_CONNECT_TIMEOUT` or a `push --json`
result with `failureKind: "serverUnavailable"` may mean Codex blocked network
access, especially for a private Retool host. Ensure the CLI runs with approved
network access and retry before concluding the host is down; follow the
[Codex Windows sandbox guide](https://learn.chatgpt.com/docs/windows/windows-sandbox)
to configure or troubleshoot the environment. `push --timeout` only controls
the post-push preview wait, not this connection.

## Pushing changes

`retool push` sends your edits through the gate and records a commit in the
app's version history. Pass a commit message with `-m` describing what changed,
so history reads clearly instead of a column of "retool push":

```
retool push -m "Add color customization panel to checkers board"
```

Write the message the way Retool summarizes a change:

- Summarize the visible result in plain English, under ~10 words.
- Focus on what the user sees ("Add dog icon to header", "Increase button
  size"), not file names, CSS properties, hex codes, or variable names.
- No markdown, no commit prefixes (`feat:`, `fix:`), no trailing period.

Without `-m` the message defaults to "retool push", so pass one on every push.

A fresh `init` is already provisioned and linked. Each push advances its branch.

## Publishing

`retool publish` takes the current branch head live and prints the public URL.
Publish when the user asks for it. Until then, the preview URL from
`push --wait` is where they review the app.

Publishing squashes: however many times you pushed, the branch lands on `main`
as one commit. Push once and that commit reuses your `-m` message; push several
times and Retool summarizes your messages into a single subject. Your
individual commits stay on the thread branch, so don't read the published
history as a sign a push went missing.

The first publish needs `--identifier <slug>` to name the public URL; without
it, publish stops and asks for one. Pick a stable, URL-safe slug; it becomes
part of the live address. Later publishes reuse the app's current identifier, so
you only pass `--identifier` again to rename.

```
retool publish --identifier refunds-dashboard
```

If a serverless function does mutating work, publish lists it as needing
approval and blocks. Pass `--approve-functions` to approve and publish in one
step (only when the mutations are expected).

## File structure

```
/backend/<area>/<entry>.ts      serverless functions — one `export default` handler per file
/backend/resources/<category>/  generated resource type declarations (read-only, git-ignored)
/frontend/pages/*.tsx           page components
/frontend/data/*.json           bulk static data, copied verbatim from the source
/frontend/lib/shadcn/           shadcn/ui components (read-only, platform-owned)
/frontend/hooks/backend/<area>.ts        generated use<Fn> hooks, one file per backend dir (read-only)
/frontend/App.tsx               routes — write this LAST
```

Import shadcn components, don't edit them. Unlike a normal shadcn project you do
not own that source: Retool ships it and `retool check` restores the canonical
contents, so an edit there is reverted and reported. To change how one looks,
wrap it in your own component under `/frontend/components/`. Trees marked
read-only or git-ignored in that layout are not for new app files either;
adding one is `nonPersistableSource`. The file can't be committed, and check
fails now so persistable files that depend on it do not break after push. Put
the file in persistable source instead.

Write files in dependency order: imported/child files before importers. The dev
server resolves imports on each write, so write `App.tsx` last.

`/backend/resources/` is grouped by resource category, not one directory per
resource. SQL resources share `sql/_client.d.ts` and `sql/_types.d.ts`; REST and
gRPC get a directory each under `restapi/` / `grpc/`; OpenAPI resources use their
type as the directory name (a Stripe resource lands in `stripe/`). These files
declare the global symbols, so read them to learn a client's API rather than to
import from.

## Data: backend functions + use<Fn> hooks

All data access goes through governed serverless functions, never direct
resource calls from the frontend.

1. A backend function is a file under `/backend/` whose default export is an
   `async` function taking zero or one arguments. Resource clients are ambient
   globals: call `retoolDb` directly, with no import. Importing one is the
   `resourceImports` failure, in backend code as much as frontend.

   Input arrives as `params` on the single argument, so a handler reading input
   reaches it as `params.x`. Any of these shapes work: destructure it
   (`{ params }`), annotate the argument (`req: { params: {...} }`), or give the
   argument a named type whose `params` property is typed. What breaks is
   flattening the wrapper away, since `{ completed }` never mentions `params`:

   ```ts
   // /backend/todos/getTodos.ts
   export default async function getTodos({ params }: { params: { completed: boolean } }) {
     const { completed } = params
     return retoolDb.query('SELECT * FROM todos WHERE completed = $1', [completed])
   }
   ```

   A handler with no arguments (`export default async function getGreeting() { ... }`)
   is also valid — skip `params` when the function takes no input. `async` is part
   of the contract: drop it and the file isn't recognized as a backend function at
   all, so no hook is generated and the frontend import fails to resolve.

2. The frontend consumes it through the generated `use<FunctionName>` hook.
   `retool init`/`check`/`start` scan `/backend` and write one hook file per
   backend directory: `/backend/<area>/<entry>.ts` becomes
   `/frontend/hooks/backend/<area>.ts`. Import from that file; don't hand-write
   these files or call the underlying `useBackendFunction` directly. `retool check`
   rejects that, and the generator overwrites the folder.

   ```tsx
   import { useGetTodos } from '../hooks/backend/functions'

   function TodoList() {
     const { data, loading, error, trigger } = useGetTodos()
     useEffect(() => {
       trigger({ completed: false })
     }, [])
     if (loading) return <div>Loading…</div>
     if (error) return <div>Error: {error}</div>
     return (
       <ul>
         {data?.map((t) => (
           <li key={t.id}>{t.title}</li>
         ))}
       </ul>
     )
   }
   ```

   Every hook returns `{ data, loading, error, trigger }`. `trigger(params?, options?)`
   runs the function, and whatever you pass as `params` is what the handler receives
   as its `params` — so `trigger({ completed: false })` reaches the handler above as
   `{ params: { completed: false } }`. Pass `{ skipCache: true }` as the second
   argument to bypass the cache.

## Current user

Read display identity with the generated frontend hook:

```tsx
import { useCurrentUser } from '../hooks/useCurrentUser'

const { user, loading } = useCurrentUser()
if (loading || !user) return null
return <div>{user.fullName}</div>
```

`user` has type `CurrentUser | null`. Check `loading` and `user` before reading
a field. Read `/frontend/hooks/useCurrentUser.ts` for the current field types.

Treat this frontend value as untrusted. Do not pass it into backend hook
`trigger(...)` parameters. `retool check` reports `currentUserSpoof` for this
flow.

Read trusted identity from `req.user` inside the backend function. Add
`user: User` to the request type. Read `/backend/user.d.ts` for its fields. Use
`req.user.id` as the stable user key. An email can be empty.

## Bulk static data: copy, don't retype

Static data that already exists in the source you're converting — records
embedded in an HTML page, a fixture, a CSV — is an asset to copy, not TypeScript
to re-author. Retyping it is the slowest part of a conversion, and it's silently
lossy: nothing diffs your literals against the source, so a dropped or mistyped
record ships unnoticed.

Extract the payload once into a JSON file under `/frontend/data/`, copy it in
verbatim, and hand-write only the types and a typed import:

```ts
// /frontend/data/report.ts
import rows from './report.json'

export type ReportRow = { id: string; owner: string; openedAt: string }
export const reportRows: ReportRow[] = rows
```

The threshold: more than roughly 50 lines of static data as TS literals means
you're transcribing. Write the JSON file instead.

## Resource-mapping rules

- Discover resources by reading `/backend/resources/`. Each resource has a `.d.ts`
  declaring the global your code calls it by, with its display name in a doc
  comment — so listing that tree tells you what exists, and opening a file tells
  you how to call it. There is no CLI command for this: the declarations are the
  catalog. `retool init` and `retool clone` pull them into place; `retool start`
  refreshes them.
- Read the category's `_client.d.ts` to learn a client's typed API before writing
  against it. To see real data and shape, run `retool resource explore`. It takes
  the backend code to run on stdin and exits 1 when stdin is empty, so send the
  code the way your own shell does it — the example below is the POSIX-shell form,
  and `cmd` and PowerShell each quote and redirect differently:

  ```
  echo "return retoolDb.query('SELECT 1')" | retool resource explore
  ```

- `explore` runs read-only code by default. A refusal **exits 1 with empty
  stdout** and prints the verdict to stderr, so read stderr (or pass `--json` and
  read `ran`/`classification`) rather than treating an empty result as no rows.
  Nothing ran, so it is a refusal to act, not a broken build. Two different
  mutative verdicts land here:

  - `mutativeCause: "write"` — a call was read and judged to write. If the user
    asked for the side effect itself (for example, a one-time schema or seed-data
    change needed to build the app), rerun the same command with
    `--allow-mutative`. This executes against the selected environment
    immediately; it is not a dry run. Otherwise, put the write in a serverless
    function under `/backend/` and keep building—do not test-run it just to
    validate the function. To see the data first, send a `SELECT` (or REST
    `GET`) instead. This verdict is not proof: only SQL is judged by parsing the
    statement, and every other resource goes by method name, so a read with an
    unrecognized name (`api.reports.exportSummary()`) lands here too. If that's
    your case, use a `get`/`list`-style method or
    `rawRequest({ method: 'GET', … })`, which are recognized as reads.
  - `mutativeCause: "unconfirmed"` — nothing writes, but the check couldn't read
    what your code does, so it won't vouch for it. Rewrite it so the call is
    plain. The check follows static strings, so a literal, a variable holding
    one, and a template of static parts all work; a value it can't trace back to
    a string does not. `retoolDb.query(buildSql())` is refused where
    `const sql = 'SELECT 1'; retoolDb.query(sql)` runs. Call the client itself
    too: `const db = retoolDb; db.query('SELECT 1')` is fine, but passing the
    client into a helper (`run(retoolDb)`) or only referencing it
    (`Object.keys(retoolDb)`) is not.

- `explore` needs **write access to every resource the code touches**, read-only
  code included. It runs in editor mode, the same bar the in-editor agent's
  `execute_backend_code` clears. Missing access is reported before anything is
  sent. Do not switch to MCP to get around it—ask for the permission, or use a
  resource you can write.

- `--allow-mutative` overrides only `mutative`. It never overrides `disallowed`,
  and it is not a substitute for the write access above.

- Explore code can `import` from other files under `/backend/`, so a helper you
  already wrote can be reused rather than pasted into the snippet.

- Bind an existing organization resource when one obviously matches. When none does,
  `retool resource create --type <type>` creates one and prints the URL where a
  human enters the credentials, so secrets are still typed into Retool rather than
  the checkout. Pass `--config` only for a headless flow that already holds the
  connection fields, and keep that file outside the repo.
- Secrets never live in the repo. Nothing imports from `/backend/resources/`, in
  either half of the app — that's the `resourceImports` failure.

## Do / don't

Do:

- Always rewrite the backend onto serverless functions on governed resources.
- Copy frontend code as-is when it already builds under Retool's Vite; rewrite
  only what won't bundle.
- Run `retool check` after each change and fix the structured errors it returns.
  It catches most of what this doc misses, but it isn't the whole gate: the
  `packageJson`, `bannedSymbols`, `resourceAcl`, and `workflowAcl` rules only run
  server-side, and the SQL rules (`queryInjection`, `sqlPlaceholderOrder`) need
  pulled resource types. `check` names what it skipped, and `push` can still
  reject work that passed locally.

Don't:

- Don't import resource clients anywhere. They're globals; an import fails
  `resourceImports` from backend and frontend files alike.
- Don't hand-write `/frontend/hooks/backend/*` or import `useBackendFunction`
  directly. The CLI generates those; import the `use<Fn>` hooks from
  `/frontend/hooks/backend/<area>.ts`. Don't import the `useBackendFunctions.ts`
  barrel either — it's a back-compat stub and is empty in the sandbox.
- Don't spoof `currentUser` or pass frontend user data into a server function's
  `params` — read `req.user` server-side instead (see "Current user").
- Don't retype bulk static data as TS literals. Copy it into a JSON file under
  `/frontend/data/` and import it.
- Don't go hunting for a running copy of the app to confirm work. `retool check`
  covers the code, and `retool resource explore` executes a backend function.
  The preview and published URLs are the user's to open. If the user explicitly
  asks you to confirm the UI renders, confirm with the user that they want to
  verify against the preview or published link, as we do not render the app
  completely locally.
