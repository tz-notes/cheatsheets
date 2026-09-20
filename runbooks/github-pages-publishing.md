# Runbook: Publish a cheatsheet repo as a GitHub Pages site

Last reviewed: 2026-09-19

**Rule zero:** a public repo is public in full: every file, every past commit, every branch. Only put generic, vetted content in it. Never put private keys, tokens, passwords, or client-specific names, hosts, or URLs in it.

**Which block do I use?** The `git` commands are identical on macOS, Linux, and Windows (PowerShell). Where something differs, the step shows a block for each.

**Contents**

<!--
  This contents list is generated. Do not edit it by hand.
  - On push to main, the "Update table of contents" workflow refreshes it.
  - To refresh it locally: bash .github/scripts/update-toc.sh
  Only the text between the START/END markers is rewritten.
-->
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [0. Quick reference](#0-quick-reference)
- [1. Which plan do I need?](#1-which-plan-do-i-need)
- [2. Audit before making the repo public](#2-audit-before-making-the-repo-public)
  - [2a. What becomes public](#2a-what-becomes-public)
  - [2b. Take inventory](#2b-take-inventory)
  - [2c. Check commit author identities](#2c-check-commit-author-identities)
  - [2d. Scan the history for secrets](#2d-scan-the-history-for-secrets)
  - [2e. Search the history for client-specific terms](#2e-search-the-history-for-client-specific-terms)
  - [2f. Check what lives outside the files](#2f-check-what-lives-outside-the-files)
  - [2g. Decide](#2g-decide)
- [3. Make the repo public](#3-make-the-repo-public)
- [4. Add the site files](#4-add-the-site-files)
- [5. Turn on GitHub Pages](#5-turn-on-github-pages)
- [6. Verify](#6-verify)
- [7. How the contents lists stay current](#7-how-the-contents-lists-stay-current)
- [8. Add another cheatsheet](#8-add-another-cheatsheet)
- [9. Take the site down or go private again](#9-take-the-site-down-or-go-private-again)
- [10. Troubleshooting](#10-troubleshooting)
- [References](#references)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 0. Quick reference

| Item | Value |
|---|---|
| Site URL | `https://<owner>.github.io/<repo>/` |
| Where to enable Pages | Repo → **Settings** → **Pages** → **Build and deployment** |
| Source to pick | **Deploy from a branch** → branch `main`, folder `/ (root)` |
| Build log | Repo → **Actions** → "pages build and deployment" |
| Entry page | `index.md` (or `README.md`) at the repo root |
| Make repo public | Repo → **Settings** → **General** → **Danger Zone** → **Change repository visibility** |

---

## 1. Which plan do I need?

| Plan | Can a private repo host Pages? | Who can open the site? |
|---|---|---|
| GitHub Free (personal or organization) | No. The repo must be public. | Anyone on the internet |
| GitHub Pro or Team | Yes | Still anyone on the internet |
| Enterprise Cloud organization | Yes | Can be restricted, but viewers must then sign in |

The goal of this runbook is to read cheatsheets **without signing in to GitHub**. That means a public site, so the free route is a public repo. A private repo on a paid plan would still serve a public site, and a truly private site needs an Enterprise Cloud organization and a login. Plan terms change, so confirm on GitHub's pricing page before you pay for anything.

---

## 2. Audit before making the repo public

Do this **before** you flip visibility. It is the step you cannot undo.

### 2a. What becomes public

Everything the repo holds, not just today's files: all commits and their diffs, all branches and tags, commit author names and emails, issues, pull requests, the wiki, releases, and Actions logs. Deleting a file later removes it from the current files but not from history, and public content gets copied quickly.

### 2b. Take inventory

Identical on every OS:

```bash
git ls-files                  # current files
git branch -a                 # all branches
git tag                       # all tags
git rev-list --all --count    # total commits across all branches
```

Confirm that every file in `git ls-files` is something you intend to publish.

### 2c. Check commit author identities

Author names and emails in every commit become public.

```bash
# macOS / Linux
git log --all --format='%an <%ae>' | sort -u
```

```powershell
# Windows (PowerShell)
git log --all --format='%an <%ae>' | Sort-Object -Unique
```

If a work or client email appears, do not publish this history. Use a fresh repo (2g). For new commits, use the private noreply address GitHub shows under **Settings** → **Emails**:

```bash
git config user.email "<your-github-noreply-address>"
```

### 2d. Scan the history for secrets

Install [gitleaks](https://github.com/gitleaks/gitleaks): `brew install gitleaks` on macOS, `scoop install gitleaks` on Windows if you use Scoop, or download a binary from its releases page. Then, from the repo folder:

```bash
gitleaks git -v                    # newer versions
gitleaks detect --source . -v      # older versions
```

`trufflehog git file://.` does the same job. Investigate every finding, even ones that look expired.

### 2e. Search the history for client-specific terms

Make a list of what must not be public: client or employer names, internal hostnames and domains, Azure DevOps organization and project names, internal IP addresses. Then search all history for each term:

```bash
git log --all --oneline -i -G"clientname"     # commits that added or removed a matching line
git grep -n -i "clientname"                   # current files only
git show <commit-hash>                        # inspect a hit
```

These commands work the same in PowerShell. Run them once per term.

### 2f. Check what lives outside the files

Look at Issues, Pull requests, the Wiki, Releases, Actions logs and artifacts, and the repo description, topics, and website field. All of it becomes public too.

### 2g. Decide

- **Nothing found:** go to step 3.
- **Anything found:** do not flip this repo. Start a fresh repo with only vetted files and no history:

```bash
mkdir cheatsheets-public && cd cheatsheets-public
git init -b main
# copy in only the reviewed files, including .github/ and runbooks/
git add . && git commit -m "Initial commit"
# create a new PUBLIC repo on GitHub, then:
git remote add origin git@github.com:<owner>/cheatsheets-public.git
git push -u origin main
```

Rewriting history with `git filter-repo` is possible but easy to get wrong. A clean start is safer.

---

## 3. Make the repo public

Repo → **Settings** → **General** → scroll to **Danger Zone** → **Change repository visibility** → **Make public**, then follow the prompts and type the repo name to confirm.

With the GitHub CLI, the same thing is:

```bash
gh repo edit <owner>/<repo> --visibility public --accept-visibility-change-consequences
```

---

## 4. Add the site files

Two files at the repo root make the site work. Both are in this repo already.

**`index.md`** is the home page. Link to each cheatsheet with a relative path to its `.md` file. GitHub Pages rewrites those links to the published pages, and the same links also work when you browse the repo on github.com.

```markdown
# Cheatsheets

- [SSH keys for GitHub and Azure DevOps](runbooks/ssh-keys-github-azdo.md)
```

**`_config.yml`** sets the title and a built-in theme:

```yaml
title: Cheatsheets
description: Quick, copy-paste runbooks
theme: jekyll-theme-primer
```

Things to know about how Pages renders this:

- Markdown files do not need front matter. GitHub Pages enables an optional-front-matter plugin by default.
- Folders and files that start with a dot or an underscore, such as `.github/`, are not published.
- Jekyll runs a template engine (Liquid) over every Markdown page. Double curly braces and percent-brace tags are treated as templates and can break the build. GitHub Actions expressions look exactly like that, so keep them out of these pages, or wrap them in Liquid's raw tag.

---

## 5. Turn on GitHub Pages

1. Repo → **Settings**.
2. In the sidebar, under **Code, planning, and automation**, click **Pages**.
3. Under **Build and deployment**, set **Source** to **Deploy from a branch**.
4. Pick the branch `main` and the folder `/ (root)`, then click **Save**.

If the site does not publish, make sure someone with admin permission and a verified email address has pushed to the publishing branch.

---

## 6. Verify

1. Repo → **Actions** → open the latest "pages build and deployment" run and wait for it to turn green. The first build usually takes a minute or two.
2. The site URL appears at the top of the **Pages** settings: `https://<owner>.github.io/<repo>/`.
3. Open it in a private or incognito window, so you know it works without a GitHub login.
4. Click a few links in each contents list and confirm they jump to the right heading. Pages renders Markdown with Jekyll, not GitHub's own renderer, so heading anchors can differ in rare cases.
5. Open it from a work laptop. Some corporate networks block `github.io`.

---

## 7. How the contents lists stay current

The workflow `.github/workflows/update-toc.yml` regenerates the contents list of every Markdown file that has the doctoc markers, then commits the result. Commits pushed by a workflow that uses the built-in `GITHUB_TOKEN` do not trigger a Pages build, so the workflow finishes by asking Pages to rebuild (`.github/scripts/request-pages-build.sh`). That step only warns if it fails, so the workflow still succeeds.

If the live site shows an outdated contents list:

1. Repo → **Actions** → "pages build and deployment" → open the latest run → **Re-run all jobs**.
2. Or push any small commit.

To refresh contents lists locally before pushing, from the repo root:

```bash
bash .github/scripts/update-toc.sh
```

---

## 8. Add another cheatsheet

1. Create `runbooks/<name>.md`.
2. Copy the `**Contents**` line and the doctoc marker block from an existing runbook into it, just below the intro.
3. Add a link to it in `index.md`.
4. Audit the new content (step 2): generic commands only.
5. Commit and push. The workflow fills in the contents list and Pages rebuilds.

---

## 9. Take the site down or go private again

- **Unpublish the site:** repo → **Settings** → **Pages** → the menu next to **Visit site** → **Unpublish site**. Menu labels can change, so look for the unpublish option in the Pages settings.
- **Make the repo private again:** repo → **Settings** → **General** → **Danger Zone** → **Change repository visibility**. On a Free plan, a private repo cannot host Pages, so the site stops being served.
- **Assume anything that was public is copied.** Forks, clones, caches, and search results can outlive the change. If a secret was ever exposed, rotate it.

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Site URL returns 404 | Build not finished, or no entry page | Wait for the Actions run to finish. Make sure `index.md` (or `README.md`) is at the repo root. |
| No **Pages** option, or it is greyed out | Free plan with a private repo | Make the repo public (step 3), or use a paid plan. |
| Build fails with a Liquid syntax error | Curly-brace or percent-brace text in a Markdown page | Remove it, or wrap it in Liquid's raw tag. |
| Build fails: theme not found | Typo in `theme:` in `_config.yml` | Use a built-in theme name such as `jekyll-theme-primer`. |
| Contents links do not jump | Heading anchor differs from what the list expects | Inspect the heading's `id` in the browser. Adjust the heading text or regenerate the list. |
| Site shows old content | Pages was not rebuilt after a bot commit | Re-run "pages build and deployment" (step 7). |
| A link to another cheatsheet 404s | Absolute path or wrong file name | Use a relative path to the `.md` file, for example `runbooks/name.md`. |
| Works at home, not on a work network | Proxy blocks `github.io` | Use another way to reach the notes, such as your phone. |

---

## References

- GitHub Docs: "Creating a GitHub Pages site" and "Configuring a publishing source for your GitHub Pages site"
- GitHub Docs: "About GitHub Pages and Jekyll"
- GitHub Docs: "GitHub's plans"
