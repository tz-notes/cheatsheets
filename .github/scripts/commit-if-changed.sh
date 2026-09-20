#!/usr/bin/env bash
#
# commit-if-changed.sh - commit and push modifications to already-tracked files.
# Intended for CI. Does nothing when the working tree is clean.
#
# Usage: commit-if-changed.sh "<commit message>"
#
# Environment:
#   GIT_USER_NAME / GIT_USER_EMAIL   author identity (default: github-actions[bot])
#   DEBUG=1                          trace every command (CI: RUNNER_DEBUG=1)
#
# In GitHub Actions it also sets the step output "committed" (true/false), so
# later steps can run only when a commit was actually pushed.

set -Eeuo pipefail

: "${GIT_USER_NAME:=github-actions[bot]}"
: "${GIT_USER_EMAIL:=41898282+github-actions[bot]@users.noreply.github.com}"

log()  { printf '[commit] %s\n' "$*"; }
set_output() { if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; fi; }
fail() { printf '[commit] ERROR: %s\n' "$*" >&2; exit 1; }
on_error() { printf '[commit] ERROR: exit %s at line %s: %s\n' "$1" "$2" "$3" >&2; }
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

if [[ "${DEBUG:-0}" == "1" || "${RUNNER_DEBUG:-0}" == "1" ]]; then
  set -x
fi

message="${1:-}"
[[ -n "$message" ]] || fail 'usage: commit-if-changed.sh "<commit message>"'

if git diff --quiet; then
  log "Working tree is clean. Nothing to commit."
  set_output committed false
  exit 0
fi

log "Changed files:"
git --no-pager diff --stat

git config user.name  "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"
git add --update            # tracked files only; never picks up stray files
git commit --message "$message"

branch="$(git branch --show-current)"
[[ -n "$branch" ]] || fail "detached HEAD; cannot push. Run the workflow from a branch."
log "Pushing to ${branch}"
git push origin "HEAD:${branch}"
set_output committed true
