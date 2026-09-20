# Runbook: SSH keys for GitHub and Azure DevOps

Last reviewed: 2026-09-19

**Rule zero:** never commit private keys or passphrases to this repo. Only commands, steps, and public config go here. Keep client-specific hostnames, orgs, and project names out of a personal repo.

**Which block do I use?**

- **macOS / Linux** → bash or zsh commands. (WSL counts as Linux and has its *own* `~/.ssh`, separate from Windows.)
- **Windows** → PowerShell commands. Run as a normal user unless the step says *admin*.
- `ssh`, `ssh-keygen`, `ssh-add`, and `git` commands are identical on every OS. Only paths, the agent, permissions, and file/clipboard helpers differ.

---

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
- [1. Check that OpenSSH and `ssh-agent` are installed](#1-check-that-openssh-and-ssh-agent-are-installed)
  - [1a. Is it installed?](#1a-is-it-installed)
  - [1b. Is the agent running?](#1b-is-the-agent-running)
  - [1c. Install it if it's missing](#1c-install-it-if-its-missing)
  - [1d. Existing keys](#1d-existing-keys)
- [2. Generate a key](#2-generate-a-key)
- [3. Start the agent and add the key](#3-start-the-agent-and-add-the-key)
- [4. Register the public key](#4-register-the-public-key)
- [5. Configure `~/.ssh/config`](#5-configure-sshconfig)
- [6. Test](#6-test)
- [7. Clone URL formats](#7-clone-url-formats)
- [8. Variations](#8-variations)
  - [Two GitHub accounts (personal + work)](#two-github-accounts-personal--work)
  - [Port 22 blocked (firewall / VPN)](#port-22-blocked-firewall--vpn)
- [9. Troubleshooting](#9-troubleshooting)
- [10. Rotate or remove a key](#10-rotate-or-remove-a-key)
- [References](#references)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 0. Quick reference

| Task | macOS / Linux | Windows (PowerShell) |
|---|---|---|
| Is OpenSSH / agent installed? | `command -v ssh ssh-agent ssh-add` | `Get-Command ssh, ssh-agent, ssh-add` |
| Is the agent running? | `ssh-add -l` | `Get-Service ssh-agent` (and `ssh-add -l`) |
| List key files | `ls -la ~/.ssh` | `Get-ChildItem -Force $env:USERPROFILE\.ssh` |
| Show public key | `cat ~/.ssh/id_ed25519_github.pub` | `Get-Content $env:USERPROFILE\.ssh\id_ed25519_github.pub` |
| Copy public key to clipboard | macOS: `pbcopy < ~/.ssh/id_ed25519_github.pub`<br>Linux: `xclip -sel clip < ~/.ssh/id_ed25519_github.pub` (or `wl-copy <`) | `Get-Content $env:USERPROFILE\.ssh\id_ed25519_github.pub \| Set-Clipboard` |
| List keys loaded in agent | `ssh-add -l` | `ssh-add -l` |
| Test GitHub | `ssh -T git@github.com` | `ssh -T git@github.com` |
| Test Azure DevOps | `ssh -T git@ssh.dev.azure.com` | `ssh -T git@ssh.dev.azure.com` |
| Debug which key is offered | `ssh -vT git@github.com` | `ssh -vT git@github.com` |
| Switch a repo from HTTPS to SSH | `git remote set-url origin <ssh-url>` | `git remote set-url origin <ssh-url>` |

---

## 1. Check that OpenSSH and `ssh-agent` are installed

Three separate questions, in this order: (a) are the tools **installed**, (b) is the agent **running**, (c) do you already have **keys**?

### 1a. Is it installed?

`ssh-agent` and `ssh-add` ship in the same package as `ssh` (the "OpenSSH client"). There is no separate agent package.

**macOS / Linux**

```bash
command -v ssh ssh-keygen ssh-agent ssh-add
ssh -V
```

Each installed tool prints its path (e.g. `/usr/bin/ssh-agent`). A missing tool prints nothing.

**Windows (PowerShell)**

```powershell
Get-Command ssh, ssh-keygen, ssh-agent, ssh-add -ErrorAction SilentlyContinue | Select-Object Name, Source
ssh -V
Get-Service ssh-agent -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
```

Installed looks like: four commands under `C:\Windows\System32\OpenSSH\`, and a `ssh-agent` service. The service is usually **Stopped / Disabled** by default, which is normal. Step 3 turns it on. If the commands or the service are missing, install it (1c).

> Git for Windows also bundles its own `ssh`, `ssh-keygen`, `ssh-agent`, and `ssh-add` (under `C:\Program Files\Git\usr\bin`) for use in Git Bash. That agent is separate from the Windows service.

### 1b. Is the agent running?

Same command on every OS:

```bash
ssh-add -l
```

| Output | Meaning |
|---|---|
| Lists one or more fingerprints | Agent running, keys loaded |
| `The agent has no identities.` | Agent running, no keys added yet (step 3) |
| `Could not open a connection to your authentication agent` (macOS/Linux) | Installed but no agent running in this shell (step 3) |
| `Error connecting to agent: No such file or directory` (Windows) | `ssh-agent` service is stopped (step 3) |
| `command not found` / `not recognized` | Not installed (1c) |

Extra checks:

```bash
# macOS / Linux: socket the shell will use, and any running agent process
echo "$SSH_AUTH_SOCK"
pgrep -u "$USER" -l ssh-agent
```

```powershell
# Windows: service state
Get-Service ssh-agent
```

### 1c. Install it if it's missing

**macOS**

OpenSSH (including `ssh-agent`) ships with macOS, and the system agent is started automatically by launchd, so it is rarely missing. If the commands aren't found, it's usually a `PATH` problem:

```bash
ls -l /usr/bin/ssh /usr/bin/ssh-agent /usr/bin/ssh-add
echo $PATH
```

If those files exist, fix your `PATH`. Prefer Apple's build over a Homebrew one, because it integrates with the macOS keychain. If you truly need another build: `brew install openssh`.

**Linux**

Install the OpenSSH client package for your distro. `ssh-agent` and `ssh-add` come with it.

| Distro family | Install command |
|---|---|
| Debian / Ubuntu / Mint | `sudo apt update && sudo apt install openssh-client` |
| Fedora / RHEL / Rocky / Alma | `sudo dnf install openssh-clients` |
| Arch / Manjaro | `sudo pacman -S openssh` |
| openSUSE | `sudo zypper install openssh-clients` (older releases: `openssh`) |

Verify:

```bash
command -v ssh-agent ssh-add
```

**Windows**

The OpenSSH Client is an optional Windows feature (Windows 10 1809+ and Windows 11; it's often preinstalled on 11).

Check and install in an *admin* PowerShell:

```powershell
Get-WindowsCapability -Online -Name 'OpenSSH.Client*'     # State: Installed or NotPresent
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

Or use the GUI: **Settings** → **System** → **Optional features** → **Add an optional feature** → **OpenSSH Client** (on Windows 10: **Settings** → **Apps** → **Optional features**).

Then **open a new terminal** so `PATH` refreshes, re-run the checks in 1a, and enable the agent service in step 3.

Alternative: install Git for Windows (`winget install --id Git.Git -e`), which brings its own OpenSSH tools for Git Bash. If you go this way, see the `core.sshCommand` note in step 3 so Git and the agent agree on which `ssh` to use.

### 1d. Existing keys

**macOS / Linux**

```bash
ls -la ~/.ssh
```

**Windows (PowerShell)**

```powershell
Get-ChildItem -Force $env:USERPROFILE\.ssh
```

Look for pairs like `id_ed25519` / `id_ed25519.pub`. The `.pub` file is the public half and is the only one you ever paste anywhere.

---

## 2. Generate a key

Use one key per service so you can revoke them independently.

**macOS / Linux**

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# GitHub (Ed25519)
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519_github

# Azure DevOps (RSA)
ssh-keygen -t rsa -b 4096 -C "you@example.com" -f ~/.ssh/id_rsa_azdo
```

**Windows (PowerShell)**

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null

# GitHub (Ed25519)
ssh-keygen -t ed25519 -C "you@example.com" -f "$env:USERPROFILE\.ssh\id_ed25519_github"

# Azure DevOps (RSA)
ssh-keygen -t rsa -b 4096 -C "you@example.com" -f "$env:USERPROFILE\.ssh\id_rsa_azdo"
```

> Azure DevOps has historically supported only RSA keys. Check the current Azure DevOps docs before using Ed25519 there; if it is supported now, use Ed25519 and drop the `ssh-rsa` lines in the config below.

Set a passphrase when prompted.

## 3. Start the agent and add the key

If `ssh-agent` isn't installed, do step 1c first.

**macOS**

The agent is already managed by the system. Add the keys and store the passphrases in the keychain:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github
ssh-add --apple-use-keychain ~/.ssh/id_rsa_azdo
```

(On macOS older than 12, use `ssh-add -K` instead of `--apple-use-keychain`.)

**Linux**

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_github
ssh-add ~/.ssh/id_rsa_azdo
```

Many desktop environments (GNOME Keyring, KDE Wallet) already run an agent. If `ssh-add -l` works without the `eval` line, skip it.

**Windows (PowerShell)**

One-time setup, in an *admin* PowerShell:

```powershell
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
```

Then, in a normal PowerShell:

```powershell
ssh-add "$env:USERPROFILE\.ssh\id_ed25519_github"
ssh-add "$env:USERPROFILE\.ssh\id_rsa_azdo"
ssh-add -l
```

If you use **Git for Windows**, make it use the Windows OpenSSH client so it talks to this agent:

```powershell
git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
```

## 4. Register the public key

**Copy the key to your clipboard first:**

```bash
# macOS
pbcopy < ~/.ssh/id_ed25519_github.pub
# Linux (X11 / Wayland)
xclip -sel clip < ~/.ssh/id_ed25519_github.pub
wl-copy < ~/.ssh/id_ed25519_github.pub
```

```powershell
# Windows
Get-Content "$env:USERPROFILE\.ssh\id_ed25519_github.pub" | Set-Clipboard
```

**GitHub**
1. GitHub → profile photo → **Settings** → **SSH and GPG keys** → **New SSH key**
2. Give it a title that names the machine (e.g. `work-laptop-2026`), type **Authentication Key**, paste, save.

Optional, with the GitHub CLI (same on all OSes): `gh ssh-key add <path-to-.pub> --title "work-laptop-2026"`

**Azure DevOps** (copy `id_rsa_azdo.pub` the same way)
1. `https://dev.azure.com/<org>` → **User settings** (top right) → **SSH public keys** → **New Key**
2. Name it, paste, save.

## 5. Configure `~/.ssh/config`

The config *contents* are the same on every OS. Only how you create and secure the file differs.

**Create/open the file**

```bash
# macOS / Linux
touch ~/.ssh/config && chmod 600 ~/.ssh/config
${EDITOR:-nano} ~/.ssh/config
```

```powershell
# Windows
New-Item -ItemType File -Force "$env:USERPROFILE\.ssh\config" | Out-Null
notepad "$env:USERPROFILE\.ssh\config"
```

> In Notepad, make sure the file is saved as `config` with **no** `.txt` extension.

**Contents**

```sshconfig
# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
    AddKeysToAgent yes

# Azure DevOps
Host ssh.dev.azure.com vs-ssh.visualstudio.com
    User git
    IdentityFile ~/.ssh/id_rsa_azdo
    IdentitiesOnly yes
    AddKeysToAgent yes
    # Only needed if you hit key-exchange / algorithm errors on newer OpenSSH:
    HostkeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
```

`~/.ssh/...` paths work in the config file on Windows too.

`IdentitiesOnly yes` stops SSH from offering every key in the agent, which avoids "too many authentication failures" and wrong-account surprises.

**macOS only:** add this block at the top of the config so the keychain is used automatically. `IgnoreUnknown` keeps the same file working on Linux and Windows, where `UseKeychain` doesn't exist.

```sshconfig
Host *
    IgnoreUnknown UseKeychain
    UseKeychain yes
```

**Permissions**

Permissions matter. SSH refuses private keys that other users can read.

```bash
# macOS / Linux
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

```powershell
# Windows: only needed if you copied a key in from elsewhere.
# Keys made by ssh-keygen on this machine are already locked down.
$key = "$env:USERPROFILE\.ssh\id_ed25519_github"
icacls $key /inheritance:r
icacls $key /grant:r "${env:USERNAME}:R"
```

## 6. Test

Same on every OS:

```bash
ssh -T git@github.com
# Success: "Hi <username>! You've successfully authenticated, but GitHub does not provide shell access."

ssh -T git@ssh.dev.azure.com
# Success: authenticates, then says shell access isn't supported. That's expected.
```

On the first connection, SSH asks you to trust the host key. Compare the fingerprint against the one published in the official GitHub / Azure DevOps docs before typing `yes`.

## 7. Clone URL formats

| Service | SSH URL |
|---|---|
| GitHub | `git@github.com:<owner>/<repo>.git` |
| Azure DevOps | `git@ssh.dev.azure.com:v3/<org>/<project>/<repo>` |

Convert an existing HTTPS clone (same on every OS):

```bash
git remote -v
git remote set-url origin git@github.com:<owner>/<repo>.git
```

---

## 8. Variations

### Two GitHub accounts (personal + work)

Give each account its own key and a host alias. Add to `~/.ssh/config` on any OS:

```sshconfig
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_personal
    IdentitiesOnly yes

Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_work
    IdentitiesOnly yes
```

Then clone with the alias as the host: `git clone git@github-work:<owner>/<repo>.git`

### Port 22 blocked (firewall / VPN)

GitHub serves SSH on 443:

```sshconfig
Host github.com
    HostName ssh.github.com
    Port 443
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
```

---

## 9. Troubleshooting

| Symptom | OS | Likely cause | Fix |
|---|---|---|---|
| `Permission denied (publickey)` | All | Key not registered, or wrong key offered | `ssh -vT git@github.com`, check which identity file is tried; confirm the `.pub` is in the web UI |
| `Too many authentication failures` | All | Agent offering many keys | Set `IdentitiesOnly yes` with an explicit `IdentityFile` |
| `ssh-add: command not found` / `'ssh-add' is not recognized` | All | OpenSSH client not installed, or not on `PATH` | See step 1c, then open a new terminal |
| `Could not open a connection to your authentication agent` | macOS / Linux | Agent not running | `eval "$(ssh-agent -s)"` |
| `Error connecting to agent: No such file or directory` | Windows | `ssh-agent` service stopped | *Admin* PowerShell: `Start-Service ssh-agent` (check with `Get-Service ssh-agent`) |
| Passphrase asked on every push | All | Key not in agent | `ssh-add <key>`, and set `AddKeysToAgent yes` (macOS: also `UseKeychain yes`) |
| `Bad permissions` / `UNPROTECTED PRIVATE KEY FILE` | macOS / Linux | `~/.ssh` or key too open | Apply the `chmod` commands in step 5 |
| `Bad permissions` / `UNPROTECTED PRIVATE KEY FILE` | Windows | Key inherited broad ACLs | Apply the `icacls` commands in step 5 |
| `Bad configuration option: usekeychain` | Linux / Windows | macOS-only option in config | Add `IgnoreUnknown UseKeychain` above it |
| `Host key verification failed` | All | Changed or untrusted host key | Verify against official docs, then `ssh-keygen -R <host>` and reconnect |
| Azure DevOps `no matching host key type` / algorithm errors | All | Newer OpenSSH disables `ssh-rsa` by default | Add the `HostkeyAlgorithms` / `PubkeyAcceptedAlgorithms` lines from step 5 |
| Works in terminal, fails in Git / IDE | Windows | Git for Windows using its bundled `ssh`, not the agent | `git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"` |
| Works in terminal, fails in IDE / GUI | macOS / Linux | GUI tool using a different agent or ssh binary | Point the tool at system OpenSSH, or check its SSH settings |
| Keys "missing" inside WSL | Windows | WSL has its own `~/.ssh` | Generate/copy keys inside WSL, or use the Windows `ssh.exe` from WSL |

---

## 10. Rotate or remove a key

1. Generate the new key (step 2) and register it (step 4).
2. Confirm it works (step 6).
3. Delete the old public key from GitHub / Azure DevOps.
4. Remove the old key from the agent and disk:

```bash
# macOS / Linux
ssh-add -d ~/.ssh/id_ed25519_github_old
rm ~/.ssh/id_ed25519_github_old ~/.ssh/id_ed25519_github_old.pub
```

```powershell
# Windows
ssh-add -d "$env:USERPROFILE\.ssh\id_ed25519_github_old"
Remove-Item "$env:USERPROFILE\.ssh\id_ed25519_github_old", "$env:USERPROFILE\.ssh\id_ed25519_github_old.pub"
```

If a laptop is lost or a key may be exposed, delete its public key from both services immediately.

---

## References

- GitHub Docs: "Connecting to GitHub with SSH"
- Microsoft Learn: "Use SSH key authentication" (Azure DevOps)
