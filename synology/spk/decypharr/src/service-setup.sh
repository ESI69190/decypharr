# Decypharr service setup for Synology DSM/SRM.
#
# Keep immutable application files below SYNOPKG_PKGDEST and persistent data
# below SYNOPKG_PKGVAR, following the same layout used by SynoCommunity
# packages such as Bazarr, Sonarr and Radarr.

PATH="${SYNOPKG_PKGDEST}/bin:${PATH}"
DECYPHARR="${SYNOPKG_PKGDEST}/bin/decypharr"

HOME_DIR="${SYNOPKG_PKGVAR}"
CONFIG_DIR="${SYNOPKG_PKGVAR}/data"
CACHE_DIR="${SYNOPKG_PKGVAR}/cache"
LOG_DIR="${SYNOPKG_PKGVAR}/logs"

SERVICE_COMMAND="env PATH=${PATH} HOME=${HOME_DIR} XDG_CACHE_HOME=${CACHE_DIR} LOG_PATH=${LOG_DIR} LD_LIBRARY_PATH=${SYNOPKG_PKGDEST}/lib UMASK=022 ${DECYPHARR} --config ${CONFIG_DIR}"

SVC_BACKGROUND=y
SVC_WRITE_PID=y
SVC_WAIT_TIMEOUT=120

create_decypharr_directories()
{
    mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${LOG_DIR}"
}

configure_fuse_helpers()
{
    # rclone's Linux mount backend calls fusermount3 explicitly, while
    # Decypharr's cgofuse backend uses FUSE2. Both helpers are designed to
    # operate setuid-root for unprivileged FUSE mounts.
    for helper in fusermount fusermount3; do
        helper_path="${SYNOPKG_PKGDEST}/bin/${helper}"
        if [ -f "${helper_path}" ]; then
            chown root:root "${helper_path}"
            chmod 4755 "${helper_path}"
        fi
    done
}

configure_fuse_conf()
{
    # Decypharr requests AllowOther for its rclone mount so Sonarr, Radarr,
    # Plex and other DSM services can access the mounted filesystem.
    # fusermount/fusermount3 permit this for a non-root package user only
    # when user_allow_other is enabled globally in /etc/fuse.conf.
    fuse_conf="/etc/fuse.conf"

    if [ ! -e "${fuse_conf}" ]; then
        touch "${fuse_conf}"
        chmod 0644 "${fuse_conf}"
    fi

    if ! grep -Eq '^[[:space:]]*user_allow_other([[:space:]]|$)' "${fuse_conf}"; then
        {
            echo ""
            echo "# Required by Decypharr for shared FUSE mounts"
            echo "user_allow_other"
        } >> "${fuse_conf}"
    fi
}

service_postinst()
{
    create_decypharr_directories
    configure_fuse_helpers
    configure_fuse_conf
}

service_postupgrade()
{
    # SYNOPKG_PKGVAR survives package upgrades. Re-create only directories
    # introduced by newer package revisions.
    create_decypharr_directories
    configure_fuse_helpers
    configure_fuse_conf
}
