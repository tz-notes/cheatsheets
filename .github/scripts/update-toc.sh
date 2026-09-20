#!/usr/bin/env bash
#
# update-toc.sh - regenerate the table of contents in Markdown files that opt in.
#
# A file opts in by containing the doctoc start marker at the start of a line:
#   <!-- START doctoc generated TOC please keep comment here to allow auto update -->
# Files without that marker are never touched.
#
# Behaves the same locally and in CI. Only git-tracked files are considered
# (`git add` a new file before running this locally).
#
# Environment (all optional):
#   TOC_MAX_LEVEL   deepest heading level to list, 1-6      (default: 3)
#   DOCTOC_VERSION  doctoc version to run through npx        (default: 2.5.0)
#   DEBUG=1         trace every command (in CI, re-run the job with
#                   "Enable debug logging" to get the same effect via RUNNER_DEBUG)
#
# Requires: bash 3.2+, git, Node.js (npx).

set -Eeuo pipefail

: "${TOC_MAX_LEVEL:=3}"
: "${DOCTOC_VERSION:=2.5.0}"
MARKER_REGEX='^<!-- START doctoc'

log()  { printf '[update-toc] %s\n' "$*"; }
fail() { printf '[update-toc] ERROR: %s\n' "$*" >&2; exit 1; }
on_error() { printf '[update-toc] ERROR: exit %s at line %s: %s\n' "$1" "$2" "$3" >&2; }
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

if [[ "${DEBUG:-0}" == "1" || "${RUNNER_DEBUG:-0}" == "1" ]]; then
  set -x
fi

# ---- Validate inputs and environment ---------------------------------------
[[ "$TOC_MAX_LEVEL" =~ ^[1-6]$ ]] || fail "TOC_MAX_LEVEL must be a number from 1 to 6 (got '${TOC_MAX_LEVEL}')"
command -v git  >/dev/null 2>&1 || fail "git is required but was not found"
command -v node >/dev/null 2>&1 || fail "Node.js is required but was not found"
command -v npx  >/dev/null 2>&1 || fail "npx is required but was not found"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "run this from inside a git repository"

cd "$(git rev-parse --show-toplevel)"

log "repo root:          ${PWD}"
log "node / npm:         $(node --version) / $(npm --version)"
log "doctoc version:     ${DOCTOC_VERSION}"
log "max heading level:  ${TOC_MAX_LEVEL}"

# ---- Find tracked Markdown files that opted in ------------------------------
files=()
while IFS= read -r -d '' f; do
  if grep -Eq "$MARKER_REGEX" "$f"; then
    files+=("$f")
  fi
done < <(git ls-files -z -- '*.md')

if [[ ${#files[@]} -eq 0 ]]; then
  log "No tracked Markdown files contain a doctoc marker. Nothing to do."
  exit 0
fi

log "opted-in files (${#files[@]}):"
printf '  - %s\n' "${files[@]}"

# ---- Regenerate --------------------------------------------------------------
npx --yes "doctoc@${DOCTOC_VERSION}" --github --notitle --maxlevel "${TOC_MAX_LEVEL}" "${files[@]}"

# ---- Report ------------------------------------------------------------------
changed_count="$(git diff --name-only -- "${files[@]}" | wc -l | tr -d ' ')"
if [[ "$changed_count" -eq 0 ]]; then
  log "Tables of contents already up to date."
else
  log "Updated ${changed_count} file(s):"
  git --no-pager diff --stat -- "${files[@]}"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Table of contents"
    echo
    echo "- Checked: ${#files[@]} file(s)  |  updated: ${changed_count}"
    echo "- Settings: max heading level ${TOC_MAX_LEVEL}, doctoc ${DOCTOC_VERSION}"
  } >> "$GITHUB_STEP_SUMMARY"
fi
