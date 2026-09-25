#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPKSRC_REF="${SPKSRC_REF:-e353e52f6117f59326550ece07ca0c68903a57fc}"
SPKSRC_DIR="${SPKSRC_DIR:-${ROOT_DIR}/.synology-build/spksrc}"
SOURCE_SHA="${DECYPHARR_GIT_HASH:-$(git -C "${ROOT_DIR}" rev-parse HEAD)}"

mkdir -p "$(dirname "${SPKSRC_DIR}")"

if [ ! -d "${SPKSRC_DIR}/.git" ]; then
    git clone https://github.com/SynoCommunity/spksrc.git "${SPKSRC_DIR}"
fi

git -C "${SPKSRC_DIR}" fetch --depth=1 origin "${SPKSRC_REF}"
git -C "${SPKSRC_DIR}" checkout --detach FETCH_HEAD

rm -rf "${SPKSRC_DIR}/cross/decypharr" "${SPKSRC_DIR}/spk/decypharr"
mkdir -p "${SPKSRC_DIR}/cross/decypharr" "${SPKSRC_DIR}/spk/decypharr/src"

cp -a "${ROOT_DIR}/synology/cross/decypharr/." "${SPKSRC_DIR}/cross/decypharr/"
cp -a "${ROOT_DIR}/synology/spk/decypharr/." "${SPKSRC_DIR}/spk/decypharr/"
cp "${ROOT_DIR}/docs/src/assets/logo.png" "${SPKSRC_DIR}/spk/decypharr/src/decypharr.png"

mkdir -p "${SPKSRC_DIR}/distrib"
ARCHIVE_NAME="decypharr-${SOURCE_SHA}.tar.gz"
ARCHIVE_PATH="${SPKSRC_DIR}/distrib/${ARCHIVE_NAME}"

git -C "${ROOT_DIR}" archive --format=tar --prefix="decypharr-${SOURCE_SHA}/" "${SOURCE_SHA}" |
    gzip -n -9 > "${ARCHIVE_PATH}"

{
    printf '%s SHA1 %s\n' "${ARCHIVE_NAME}" "$(sha1sum "${ARCHIVE_PATH}" | awk '{print $1}')"
    printf '%s SHA256 %s\n' "${ARCHIVE_NAME}" "$(sha256sum "${ARCHIVE_PATH}" | awk '{print $1}')"
    printf '%s MD5 %s\n' "${ARCHIVE_NAME}" "$(md5sum "${ARCHIVE_PATH}" | awk '{print $1}')"
} > "${SPKSRC_DIR}/cross/decypharr/digests"

cat <<EOF
spksrc prepared in: ${SPKSRC_DIR}
source commit:       ${SOURCE_SHA}

Build example:
  DECYPHARR_GIT_HASH=${SOURCE_SHA} DECYPHARR_VERSION=0.0.0-dev \
    make -C "${SPKSRC_DIR}/spk/decypharr" arch-x64-7.2
EOF
