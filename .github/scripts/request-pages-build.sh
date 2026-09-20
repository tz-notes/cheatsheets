#!/usr/bin/env bash
#
# request-pages-build.sh - ask GitHub to rebuild the GitHub Pages site.
#
# Why: commits pushed by a workflow using the GITHUB_TOKEN do not trigger a
# Pages build on their own, so a bot commit would otherwise leave the live site
# one push behind.
#
# Non-fatal by design: if Pages is not enabled yet, or the call is rejected, this
# prints a warning and exits 0 so the workflow still succeeds.
#
# Requires: gh (preinstalled on GitHub-hosted runners), GH_TOKEN, GITHUB_REPOSITORY.
# The job needs "pages: write" permission.
#
# Environment:
#   DEBUG=1   trace every command (CI: RUNNER_DEBUG=1)

set -Eeuo pipefail

log()  { printf '[pages] %s\n' "$*"; }
warn() { printf '::warning::[pages] %s\n' "$*"; }
on_error() { printf '[pages] ERROR: exit %s at line %s: %s\n' "$1" "$2" "$3" >&2; }
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

if [[ "${DEBUG:-0}" == "1" || "${RUNNER_DEBUG:-0}" == "1" ]]; then
  set -x
fi

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set (this script is meant to run in GitHub Actions)}"
command -v gh >/dev/null 2>&1 || { warn "gh CLI not found; skipping Pages rebuild request."; exit 0; }

log "Requesting a Pages build for ${GITHUB_REPOSITORY}"
if out="$(gh api --method POST "repos/${GITHUB_REPOSITORY}/pages/builds" 2>&1)"; then
  log "Build requested."
else
  warn "Could not request a Pages build (is Pages enabled, and does the job have pages: write?). Response: ${out}"
fi
