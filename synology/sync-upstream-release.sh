#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

UPSTREAM_REPO="${UPSTREAM_REPO:-sirrobot01/decypharr}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

log() {
    printf '[upstream-sync] %s\n' "$*"
}

TAG="$(gh api "repos/${UPSTREAM_REPO}/releases/latest" --jq '.tag_name')"
VERSION="${TAG#v}"
SYNC_BRANCH="sync/upstream-${TAG}"

log "Latest upstream stable release: ${TAG}"

if gh release view "${TAG}" --repo "${GITHUB_REPOSITORY}" >/dev/null 2>&1; then
    {
        echo "## Stable upstream sync"
        echo
        echo "Downstream release `${TAG}` already exists. Nothing to do."
    } >> "${SUMMARY}"
    exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git remote add upstream "https://github.com/${UPSTREAM_REPO}.git" 2>/dev/null ||     git remote set-url upstream "https://github.com/${UPSTREAM_REPO}.git"

git fetch origin main
git fetch --force upstream "refs/tags/${TAG}:refs/tags/upstream-${TAG}"

UPSTREAM_SHA="$(git rev-list -n 1 "refs/tags/upstream-${TAG}")"

log "Upstream commit: ${UPSTREAM_SHA}"

git switch -C "${SYNC_BRANCH}" origin/main

if ! git merge --no-ff "refs/tags/upstream-${TAG}" -m "Sync upstream ${TAG}"; then
    git status --short
    git merge --abort || true
    {
        echo "## Stable upstream sync failed"
        echo
        echo "Merge conflict while integrating `${TAG}`."
        echo
        echo "Downstream `main` and the published Synology release were not modified."
    } >> "${SUMMARY}"
    exit 1
fi

printf '%s\n' "${VERSION}" > synology/UPSTREAM_VERSION
printf '%s\n' "${UPSTREAM_SHA}" > synology/UPSTREAM_SHA

git add synology/UPSTREAM_VERSION synology/UPSTREAM_SHA
if ! git diff --cached --quiet; then
    git commit -m "chore(sync): pin upstream ${TAG}"
fi

git push --force origin "HEAD:refs/heads/${SYNC_BRANCH}"

log "Building DSM 7.3 avoton package before promotion"

export DECYPHARR_GIT_HASH="${UPSTREAM_SHA}"
export DECYPHARR_VERSION="${VERSION}"
export SPKSRC_DIR="${GITHUB_WORKSPACE}/.synology-build/spksrc"

bash synology/prepare-spksrc.sh

docker run --rm     -e DECYPHARR_GIT_HASH     -e DECYPHARR_VERSION     -v "${SPKSRC_DIR}:/spksrc"     -w /spksrc     ghcr.io/synocommunity/spksrc:latest     make -C spk/decypharr arch-avoton-7.3 SPK_PACKAGE_ARCHS=avoton

mkdir -p release
mapfile -t packages < <(find "${SPKSRC_DIR}/packages" -maxdepth 1 -type f -name 'decypharr*.spk' -print | sort)

if [[ "${#packages[@]}" -ne 1 ]]; then
    echo "Expected exactly one Decypharr SPK, found ${#packages[@]}" >&2
    printf '%s\n' "${packages[@]}" >&2
    exit 1
fi

SPK="release/decypharr-${VERSION}-dsm7.3-avoton.spk"
cp "${packages[0]}" "${SPK}"
(
    cd release
    sha256sum "$(basename "${SPK}")" > SHA256SUMS
)

log "Package validated: ${SPK}"

PR_NUMBER="$(gh pr list     --repo "${GITHUB_REPOSITORY}"     --head "${SYNC_BRANCH}"     --base main     --state open     --json number     --jq '.[0].number // empty')"

if [[ -z "${PR_NUMBER}" ]]; then
    PR_URL="$(gh pr create         --repo "${GITHUB_REPOSITORY}"         --base main         --head "${SYNC_BRANCH}"         --title "Sync upstream ${TAG}"         --body "Automated stable synchronization from `sirrobot01/decypharr`.

Upstream tag: `${TAG}`
Upstream commit: `${UPSTREAM_SHA}`

DSM 7.3 avoton was built successfully before promotion.")"
    PR_NUMBER="${PR_URL##*/}"
fi

log "Merging audit PR #${PR_NUMBER}"

gh pr merge "${PR_NUMBER}"     --repo "${GITHUB_REPOSITORY}"     --merge

MERGE_SHA="$(gh pr view "${PR_NUMBER}"     --repo "${GITHUB_REPOSITORY}"     --json mergeCommit     --jq '.mergeCommit.oid')"

UPSTREAM_URL="$(gh api "repos/${UPSTREAM_REPO}/releases/tags/${TAG}" --jq '.html_url')"

cat > release/RELEASE_NOTES.md <<EOF
Native Synology DSM 7.3 avoton package for Decypharr ${TAG}.

Upstream release: ${UPSTREAM_URL}

This package is built from upstream commit `${UPSTREAM_SHA}` and applies the maintained Synology compatibility layer at package build time.
EOF

if ! gh release view "${TAG}" --repo "${GITHUB_REPOSITORY}" >/dev/null 2>&1; then
    gh release create "${TAG}"         --repo "${GITHUB_REPOSITORY}"         --target "${MERGE_SHA}"         --title "decypharr ${TAG}"         --notes-file release/RELEASE_NOTES.md
fi

gh release upload "${TAG}"     "${SPK}" release/SHA256SUMS     --repo "${GITHUB_REPOSITORY}"     --clobber

git push origin --delete "${SYNC_BRANCH}" || true

{
    echo "## Stable upstream release promoted"
    echo
    echo "- upstream tag: `${TAG}`"
    echo "- upstream SHA: `${UPSTREAM_SHA}`"
    echo "- downstream merge: `${MERGE_SHA}`"
    echo "- package: `$(basename "${SPK}")`"
} >> "${SUMMARY}"
