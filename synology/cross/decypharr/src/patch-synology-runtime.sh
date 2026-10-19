#!/bin/sh
set -eu

GO_SRC_DIR="$1"
DOWNLOADER="${GO_SRC_DIR}/pkg/manager/downloader.go"
QBIT_TYPES="${GO_SRC_DIR}/pkg/server/qbit/types.go"

for file in "${DOWNLOADER}" "${QBIT_TYPES}"; do
    if [ ! -f "${file}" ]; then
        echo "Synology runtime patch: expected source file missing: ${file}" >&2
        exit 1
    fi
done

# Synology Arr imports must never create an empty symlink job. Keep this patch
# in the private packaging copy so upstream Go sources remain untouched.
if ! grep -q 'no active media files available for symlink action' "${DOWNLOADER}"; then
    perl -0pi -e 's/(func \(d \*Downloader\) processSymlink\(entry \*storage\.Entry, mountPath string\) error \{\n\tfiles := entry\.GetActiveFiles\(\)\n)/$1\tif len(files) == 0 {\n\t\treturn fmt.Errorf("no active media files available for symlink action: %s", entry.Name)\n\t}\n/' "${DOWNLOADER}"
fi

# With the package service UMASK=022, MkdirAll(..., 0777) becomes 0755.
# Radarr/Sonarr share the synocommunity group and need the leaf directory
# group-writable to move/delete completed imports.
if ! grep -q 'failed to set directory permissions' "${DOWNLOADER}"; then
    perl -0pi -e 's/(\terr := os\.MkdirAll\(torrentSymlinkPath, os\.ModePerm\)\n\tif err != nil \{\n\t\treturn fmt\.Errorf\("failed to create directory: %s: %v", torrentSymlinkPath, err\)\n\t\}\n)/$1\tif err := os.Chmod(torrentSymlinkPath, 0o775); err != nil {\n\t\treturn fmt.Errorf("failed to set directory permissions: %s: %v", torrentSymlinkPath, err)\n\t}\n/' "${DOWNLOADER}"
fi

# Tell Arr applications that completed Decypharr items are removable. This
# allows native ImportMode.Move instead of Copy.
sed -i -E 's/MaxRatio:[[:space:]]+-1,/MaxRatio:                           1,/' "${QBIT_TYPES}"
sed -i -E 's/MaxRatioAct:[[:space:]]+0,/MaxRatioAct:                        1,/' "${QBIT_TYPES}"
sed -i -E 's/MaxRatioEnabled:[[:space:]]+false,/MaxRatioEnabled:                    true,/' "${QBIT_TYPES}"

grep -q 'no active media files available for symlink action' "${DOWNLOADER}" || {
    echo "Synology runtime patch: empty symlink guard was not applied" >&2
    exit 1
}
grep -q 'failed to set directory permissions' "${DOWNLOADER}" || {
    echo "Synology runtime patch: 0775 symlink directory patch was not applied" >&2
    exit 1
}
grep -q 'MaxRatioEnabled:[[:space:]]*true' "${QBIT_TYPES}" || {
    echo "Synology runtime patch: Arr Move import compatibility was not applied" >&2
    exit 1
}
