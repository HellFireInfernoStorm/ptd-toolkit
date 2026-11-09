#!/usr/bin/env bash
# bootstrap.sh — one-shot setup of the PTD exam toolkit on a fresh Kali box.
#
# Download & run (public repo, no login needed):
#   curl -fsSL https://raw.githubusercontent.com/HellFireInfernoStorm/ptd-toolkit/main/bootstrap.sh | bash
# or:
#   wget https://raw.githubusercontent.com/HellFireInfernoStorm/ptd-toolkit/main/bootstrap.sh
#   bash bootstrap.sh
#
# Does: install git -> clone/update repo -> setup.sh (apt deps + wordlists + aliases) ->
#       fetch-binaries.sh -> wire aliases into your shell rc.
# Env toggles:  DEST=/path (default ~/ptd-toolkit)   SKIP_APT=1   SKIP_FETCH=1
set -uo pipefail

REPO="https://github.com/HellFireInfernoStorm/ptd-toolkit.git"
DEST="${DEST:-$HOME/ptd-toolkit}"

say(){ printf '\033[36m[bootstrap]\033[0m %s\n' "$*"; }
err(){ printf '\033[31m[bootstrap]\033[0m %s\n' "$*" >&2; }

# 1) git present? -------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  say "Installing git..."
  sudo apt-get update -y && sudo apt-get install -y git || { err "could not install git"; exit 1; }
fi

# 2) clone or update ----------------------------------------------------------
if [ -d "$DEST/.git" ]; then
  say "Repo already at $DEST — updating."
  git -C "$DEST" config core.fileMode false          # ignore exec-bit drift
  git -C "$DEST" pull --ff-only || err "git pull failed — resolve manually in $DEST, then re-run."
else
  say "Cloning $REPO -> $DEST"
  git clone "$REPO" "$DEST" || { err "clone failed (network?)"; exit 1; }
  git -C "$DEST" config core.fileMode false
fi

cd "$DEST" || { err "cannot cd into $DEST"; exit 1; }

# 3) setup: apt deps + wordlists + aliases + tool check -----------------------
say "Running setup.sh ..."
bash setup.sh

# 4) fetch privesc/enum binaries (retries handle transient GitHub 504s) -------
if [ "${SKIP_FETCH:-0}" = "1" ]; then
  say "SKIP_FETCH=1 — skipping binary download."
else
  say "Fetching privesc/enum binaries ..."
  bash scripts/fetch-binaries.sh || err "some binaries failed — just re-run: bash scripts/fetch-binaries.sh"
fi

# 5) load aliases in every new shell ------------------------------------------
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  if ! grep -qF "ptd-toolkit/aliases.sh" "$rc" 2>/dev/null; then
    echo "source \"$DEST/aliases.sh\"" >> "$rc" && say "Wired aliases into $(basename "$rc")"
  fi
done

echo
say "Done. Toolkit at: $DEST"
echo "  Load aliases into THIS shell now:   source \"$DEST/aliases.sh\""
echo "  (new terminals load them automatically)"
echo "  Then on the target:  sett <target-ip> ; bash scripts/recon.sh \$RHOST"
echo "  Drive from:          $DEST/cheatsheets/00-KILLCHAIN.md"
