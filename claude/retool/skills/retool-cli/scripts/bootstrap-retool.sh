#!/bin/sh
set -eu

if [ "$#" -gt 2 ]; then
  echo "usage: bootstrap-retool.sh [persistent-workspace] [retool-host-url]" >&2
  exit 2
fi

workspace_input=${1:-"$PWD"}
retool_host=${2:-}
if [ ! -d "$workspace_input" ]; then
  echo "retool bootstrap: workspace does not exist: $workspace_input" >&2
  exit 1
fi
case "$retool_host" in
  "" | http://* | https://*) ;;
  *)
    echo "retool bootstrap: Retool host URL must be a full http(s) URL: $retool_host" >&2
    exit 2
    ;;
esac
carriage_return=$(printf '\r')
case "$retool_host" in
  *'
'* | *"$carriage_return"*)
    echo "retool bootstrap: Retool host URL must fit on one line" >&2
    exit 2
    ;;
esac
if [ -n "$retool_host" ]; then
  if ! retool_host=$(node -e '
    const value = process.argv[1]
    try {
      const url = new URL(value)
      if (url.hostname === "" || (url.protocol !== "http:" && url.protocol !== "https:")) {
        process.exit(1)
      }
      process.stdout.write(url.origin)
    } catch {
      process.exit(1)
    }
  ' "$retool_host"); then
    echo "retool bootstrap: Retool host URL must be a full http(s) URL: $retool_host" >&2
    exit 2
  fi
fi

workspace_root=$(CDPATH= cd -- "$workspace_input" && pwd -P)
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
# The plugin builder injects the generated launcher beside this script when it
# assembles the distributable artifact; the launcher is not checked-in source.
launcher_source="$script_dir/retool-launcher.cjs"

if [ ! -f "$launcher_source" ]; then
  echo "retool bootstrap: bundled launcher is missing: $launcher_source" >&2
  echo "retool bootstrap: run this script from an assembled Retool plugin" >&2
  exit 1
fi

if command -v git >/dev/null 2>&1; then
  # Protect credentials even when bootstrap runs before `git init`. Git applies
  # this user-level excludes file to repositories initialized later in the same
  # sandbox session. Once a repository exists, its private exclude below makes
  # the protection persistent with the connected workspace.
  global_exclude_path=$(git config --global --path core.excludesFile 2>/dev/null || true)
  if [ -z "$global_exclude_path" ]; then
    global_exclude_path="${XDG_CONFIG_HOME:-${HOME:?HOME is not set}/.config}/git/ignore"
  fi
  mkdir -p "$(dirname -- "$global_exclude_path")"
  if ! grep -Fqx '.retool/' "$global_exclude_path" 2>/dev/null; then
    printf '.retool/\n' >> "$global_exclude_path"
  fi

  git_root=$(git -C "$workspace_root" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$git_root" ]; then
    git_root=$(CDPATH= cd -- "$git_root" && pwd -P)
    if [ "$git_root" != "$workspace_root" ]; then
      echo "retool bootstrap: workspace is inside Git repository $git_root" >&2
      echo "retool bootstrap: rerun from the repository root so .retool/ stays private" >&2
      exit 1
    fi
    exclude_path=$(git -C "$workspace_root" rev-parse --git-path info/exclude)
    case "$exclude_path" in
      /*) ;;
      *) exclude_path="$workspace_root/$exclude_path" ;;
    esac
    mkdir -p "$(dirname -- "$exclude_path")"
    if ! grep -Fqx '.retool/' "$exclude_path" 2>/dev/null; then
      printf '.retool/\n' >> "$exclude_path"
    fi
  fi
fi

session_root="${HOME:?HOME is not set}/.retool"
bin_dir="$session_root/bin"
persistent_root="$workspace_root/.retool"

mkdir -p "$bin_dir" "$persistent_root"
chmod 700 "$session_root" "$bin_dir" "$persistent_root"
cp "$launcher_source" "$bin_dir/retool-launcher.cjs"
chmod 644 "$bin_dir/retool-launcher.cjs"

printf '%s\n' "$workspace_root" > "$session_root/workspace-root"
chmod 600 "$session_root/workspace-root"
# Keep the host as data instead of interpolating an arbitrary URL into the
# generated shell. Writing the empty value also clears an earlier binding.
printf '%s\n' "$retool_host" > "$session_root/retool-host"
chmod 600 "$session_root/retool-host"

{
  printf '%s\n' '#!/bin/sh'
  printf '%s\n' 'set -eu'
  printf '%s\n' 'workspace_root='
  printf '%s\n' 'retool_host='
  printf '%s\n' 'IFS= read -r workspace_root < "$HOME/.retool/workspace-root"'
  printf '%s\n' 'IFS= read -r retool_host < "$HOME/.retool/retool-host"'
  printf '%s\n' 'if [ -z "$workspace_root" ] || [ ! -d "$workspace_root" ]; then'
  printf '%s\n' '  echo "retool: persistent workspace is unavailable; rerun bootstrap-retool.sh with a workspace mounted into this sandbox" >&2'
  printf '%s\n' '  exit 1'
  printf '%s\n' 'fi'
  printf '%s\n' 'export NODE_USE_ENV_PROXY="${NODE_USE_ENV_PROXY:-1}"'
  printf '%s\n' 'export RETOOL_CREDENTIALS_PATH="${RETOOL_CREDENTIALS_PATH:-$workspace_root/.retool/credentials.json}"'
  printf '%s\n' 'export RETOOL_CLI_STATE_DIR="${RETOOL_CLI_STATE_DIR:-$workspace_root/.retool/cli}"'
  printf '%s\n' 'if [ -n "$retool_host" ]; then'
  printf '%s\n' '  export RETOOL_HOST="${RETOOL_HOST:-$retool_host}"'
  printf '%s\n' 'fi'
  printf '%s\n' 'exec node "$HOME/.retool/bin/retool-launcher.cjs" "$@"'
} > "$bin_dir/retool"
chmod 700 "$bin_dir/retool"

printf 'Retool CLI bootstrapped for this session.\n'
printf '  Workspace:   %s\n' "$workspace_root"
if [ -n "$retool_host" ]; then
  printf '  Retool host:  %s\n' "$retool_host"
else
  printf '  Retool host:  CLI default\n'
fi
printf '  Credentials: %s\n' "$persistent_root/credentials.json"
printf '  CLI cache:   %s\n' "$persistent_root/cli"
printf 'Next: export PATH="$HOME/.retool/bin:$PATH"\n'
