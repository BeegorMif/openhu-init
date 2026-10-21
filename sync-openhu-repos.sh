#!/usr/bin/env bash
# Clone or fast-forward the OpenHU repositories used for Raspberry Pi testing.
# Usage: ./sync-openhu-repos.sh [workspace-directory]
# Default workspace: ~/openhu

set -Eeuo pipefail

BASE_DIR="${1:-${OPENHU_WORKSPACE:-$HOME/openhu}}"
mkdir -p "$BASE_DIR"
BASE_DIR="$(cd "$BASE_DIR" && pwd -P)"

sync_repo() {
    local name url branch dir
    name="$1"
    url="$2"
    branch="$3"
    dir="$BASE_DIR/$name"

    if [[ ! -e "$dir" ]]; then
        printf 'Cloning %s (%s, branch %s)\n' "$name" "$url" "$branch"
        git clone --branch "$branch" --single-branch "$url" "$dir"
        return
    fi

    if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'ERROR: %s exists but is not a Git checkout: %s\n' "$name" "$dir" >&2
        return 1
    fi

    local actual_url current_branch migrate_aasdk_origin=false
    actual_url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
    if [[ "${actual_url,,}" != "${url,,}" && "${actual_url,,}" != "${url,,}.git" ]]; then
        case "${name}:${actual_url,,}" in
            aasdk-ref:https://github.com/average-web-dev/aasdk|\
            aasdk-ref:https://github.com/average-web-dev/aasdk.git|\
            aasdk-ref:git@github.com:average-web-dev/aasdk.git|\
            aasdk-ref:ssh://git@github.com/average-web-dev/aasdk.git)
                migrate_aasdk_origin=true
                ;;
            *)
                printf 'ERROR: %s has unexpected origin:\n  found:    %s\n  expected: %s\n' \
                    "$name" "${actual_url:-<no origin>}" "$url" >&2
                return 1
                ;;
        esac
    fi

    if [[ -n "$(git -C "$dir" status --porcelain --untracked-files=normal)" ]]; then
        printf 'ERROR: %s has local changes; commit or stash them before syncing: %s\n' "$name" "$dir" >&2
        return 1
    fi

    current_branch="$(git -C "$dir" branch --show-current)"
    if [[ "$current_branch" != "$branch" ]]; then
        printf 'ERROR: %s is on branch %s; expected %s. Switch branches yourself, then rerun.\n' \
            "$name" "${current_branch:-<detached HEAD>}" "$branch" >&2
        return 1
    fi

    printf 'Updating %s\n' "$name"
    if [[ "$migrate_aasdk_origin" == true ]]; then
        printf 'Migrating the clean AASDK checkout from average-web-dev to %s\n' "$url"
        git -C "$dir" fetch "$url" "$branch"
        git -C "$dir" merge --ff-only FETCH_HEAD
        git -C "$dir" remote set-url origin "$url"
    else
        git -C "$dir" fetch --prune origin
        git -C "$dir" merge --ff-only "origin/$branch"
    fi
}

sync_repo openhu https://github.com/BeegorMif/openhu.git main
sync_repo openhu-os https://github.com/BeegorMif/openhu-os.git main
sync_repo openhu-plugins https://github.com/BeegorMif/openhu-plugins.git main
# OpenHU builds against the compatible AASDK branch in the user's fork.
sync_repo aasdk-ref https://github.com/BeegorMif/aasdk.git openhu

cat <<EOF

All repositories are current under: $BASE_DIR

On Raspberry Pi OS based on Debian Trixie, build the OpenHU package with:
  cd "$BASE_DIR/openhu"
  ./build.sh release --aasdk-path ../aasdk-ref --package --output-dir ./packages

Then install the packages and start OpenHU:
  sudo apt install ./packages/libaasdk_*_arm64.deb ./packages/openhu_*_arm64.deb
  mkdir -p ~/.config/openhu
  cd ~/.config/openhu
  openhu

This installs/runs OpenHU on Raspberry Pi OS; it does not build or install the OpenHU OS image.
EOF
