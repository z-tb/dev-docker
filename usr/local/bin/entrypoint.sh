#!/bin/bash
set -euo pipefail

DOCKER_SOCKET=/var/run/docker.sock

# Colorize stderr only when attached to a terminal.
if [[ -t 2 && "${TERM:-dumb}" != "dumb" && -z "${NO_COLOR+x}" ]]; then
    C_RESET=$'\033[0m'
    C_DIM=$'\033[2m'
    C_BLUE=$'\033[34m'
    C_GREEN=$'\033[32m'
    C_CYAN=$'\033[36m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
else
    C_RESET=''
    C_DIM=''
    C_BLUE=''
    C_GREEN=''
    C_CYAN=''
    C_YELLOW=''
    C_RED=''
fi

log_group() {
    local action="$1"
    local name="$2"
    local gid="$3"

    printf '%s[entrypoint]%s %s%-8s%s group=%s%s%s gid=%s%s%s\n' \
        "$C_DIM" "$C_RESET" \
        "$C_GREEN" "$action" "$C_RESET" \
        "$C_CYAN" "$name" "$C_RESET" \
        "$C_YELLOW" "$gid" "$C_RESET" >&2
}

log_group_mapping() {
    local host_name="$1"
    local gid="$2"
    local container_name="$3"

    printf '%s[entrypoint]%s %s%-8s%s host=%s%s%s container=%s%s%s gid=%s%s%s\n' \
        "$C_DIM" "$C_RESET" \
        "$C_BLUE" "Mapped" "$C_RESET" \
        "$C_CYAN" "$host_name" "$C_RESET" \
        "$C_CYAN" "$container_name" "$C_RESET" \
        "$C_YELLOW" "$gid" "$C_RESET" >&2
}

log_error() {
    printf '%s[entrypoint]%s %s%-8s%s %s\n' \
        "$C_DIM" "$C_RESET" \
        "$C_RED" "Error" "$C_RESET" "$*" >&2
}

if [[ -z "${USER_NAME:-}" ]]; then
    log_error "USER_NAME must be set."
    exit 1
fi

# Support docker run --user when passwordless sudo is available.
if [[ "$(id -u)" -ne 0 ]]; then
    exec sudo -n -E -u root -- /usr/local/bin/entrypoint.sh "$@"
fi

# The target user must already exist.
if ! id "$USER_NAME" >/dev/null 2>&1; then
    log_error "Target user does not exist: $USER_NAME"
    exit 1
fi

# Include the Docker socket's GID before processing supplementary groups.
if [[ -S "$DOCKER_SOCKET" ]]; then
    DOCKER_SOCKET_GID=$(stat -Lc '%g' -- "$DOCKER_SOCKET")

    USER_GROUPS="${USER_GROUPS:+${USER_GROUPS},}docker:${DOCKER_SOCKET_GID}"

    log_group "Detected" "$DOCKER_SOCKET" "$DOCKER_SOCKET_GID"
fi

# Format: "group1:gid1,group2:gid2"
if [[ -n "${USER_GROUPS:-}" ]]; then
    IFS=',' read -ra GROUPS_ARRAY <<< "$USER_GROUPS"

    for ITEM in "${GROUPS_ARRAY[@]}"; do
        if [[ ! "$ITEM" =~ ^([^:[:space:]]+):([0-9]+)$ ]]; then
            log_error "Invalid USER_GROUPS entry: $ITEM"
            exit 1
        fi

        GNAME="${BASH_REMATCH[1]}"
        GID="${BASH_REMATCH[2]}"

        # Normalize decimal GIDs, including leading zeros.
        GID=$((10#$GID))

        # Reuse an existing group with the required numeric GID.
        if GROUP_ENTRY=$(getent group "$GID"); then
            TARGET_GROUP="${GROUP_ENTRY%%:*}"
        else
            TARGET_GROUP="$GNAME"

            # Preserve existing container groups with different GIDs.
            if getent group "$TARGET_GROUP" >/dev/null; then
                TARGET_GROUP="${GNAME}.h"
            fi

            if getent group "$TARGET_GROUP" >/dev/null; then
                TARGET_GROUP="${GNAME}.h${GID}"
            fi

            SUFFIX=1
            BASE_GROUP="$TARGET_GROUP"

            while getent group "$TARGET_GROUP" >/dev/null; do
                TARGET_GROUP="${BASE_GROUP}.${SUFFIX}"
                SUFFIX=$((SUFFIX + 1))
            done

            if ! groupadd -g "$GID" "$TARGET_GROUP"; then
                log_error "Could not create group: $TARGET_GROUP (GID $GID)"
                exit 1
            fi

            log_group "Created" "$TARGET_GROUP" "$GID"
        fi

        # Ensure membership even when the group already exists.
        if ! usermod -aG "$TARGET_GROUP" "$USER_NAME"; then
            log_error "Could not add $USER_NAME to group: $TARGET_GROUP"
            exit 1
        fi

        log_group_mapping "$GNAME" "$GID" "$TARGET_GROUP"
    done
fi

# Default to Bash if no command was supplied.
if [[ "$#" -eq 0 ]]; then
    set -- /bin/bash
fi

# Start the command as the user with updated group memberships.
exec sudo -n -E -u "$USER_NAME" -- "$@"