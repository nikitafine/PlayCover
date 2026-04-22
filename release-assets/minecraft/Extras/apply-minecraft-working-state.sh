#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SNAPSHOT_DIR="${BASE_DIR}/working-state"

PLAYCOVER_APP="/Applications/PlayCover.app"
PLAYTOOLS_EMBEDDED="${PLAYCOVER_APP}/Contents/Frameworks/PlayTools.framework"
PLAYTOOLS_USER="${HOME}/Library/Frameworks/PlayTools.framework"
PLAYCOVER_SETTINGS_DIR="${HOME}/Library/Containers/io.playcover.PlayCover/App Settings"
PLAYCOVER_APPS_DIR="${HOME}/Library/Containers/io.playcover.PlayCover/Applications"
APP_READY_POLL_INTERVAL=2
APP_READY_TIMEOUT=60
TEMP_ENTITLEMENTS=""

cleanup() {
    if [ -n "${TEMP_ENTITLEMENTS}" ] && [ -f "${TEMP_ENTITLEMENTS}" ]; then
        rm -f "${TEMP_ENTITLEMENTS}"
    fi
}

trap cleanup EXIT

find_minecraft_app() {
    for candidate in \
        "${PLAYCOVER_APPS_DIR}/Minecraft.app" \
        "${PLAYCOVER_APPS_DIR}/com.mojang.minecraftpe.app"
    do
        if [ -d "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

find_minecraft_launcher() {
    for candidate in \
        "${HOME}/Applications/PlayCover/Minecraft.app" \
        "${HOME}/Applications/PlayCover/com.mojang.minecraftpe.app"
    do
        if [ -d "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

wait_for_minecraft_app_ready() {
    elapsed=0
    stable_polls=0
    last_path=""

    while [ "${elapsed}" -lt "${APP_READY_TIMEOUT}" ]; do
        current_path="$(find_minecraft_app || true)"

        if [ -n "${current_path}" ] \
           && [ -f "${current_path}/Info.plist" ] \
           && [ -x "${current_path}/minecraftpe" ]; then
            if [ "${current_path}" = "${last_path}" ]; then
                stable_polls=$((stable_polls + 1))
            else
                stable_polls=1
                last_path="${current_path}"
            fi

            if [ "${stable_polls}" -ge 3 ]; then
                printf '%s\n' "${current_path}"
                return 0
            fi
        else
            stable_polls=0
            last_path=""
        fi

        sleep "${APP_READY_POLL_INTERVAL}"
        elapsed=$((elapsed + APP_READY_POLL_INTERVAL))
    done

    return 1
}

write_launcher_script() {
    launcher_bin="$1"
    app_exec="$2"

    cat > "${launcher_bin}" <<EOF
#!/bin/zsh
APP_BUNDLE='${MC_APP}'
APP_EXEC='${app_exec}'
APP_NAME='${app_exec##*/}'
POLL_INTERVAL=2
BACKGROUND_POLLS_TO_KILL=4

app_phase_for_pid() {
    local pid="\$1"
    local info

    info=\$(lsappinfo info -app "\$pid" 2>/dev/null || true)
    if [[ -z "\$info" ]]; then
        printf '%s\n' 'missing'
    elif printf '%s' "\$info" | grep -q 'type="Foreground"'; then
        printf '%s\n' 'foreground'
    else
        printf '%s\n' 'background'
    fi
}

watch_for_lingering_process() {
    local pid="\$1"
    local saw_foreground=0
    local background_polls=0
    local phase
    local watch_lock_dir="/tmp/playcover-watch-\${APP_NAME}-\${pid}"

    if ! mkdir "\$watch_lock_dir" 2>/dev/null; then
        return 0
    fi
    trap 'rmdir "\$watch_lock_dir" >/dev/null 2>&1 || true' EXIT

    while kill -0 "\$pid" > /dev/null 2>&1; do
        phase=\$(app_phase_for_pid "\$pid")

        if [[ "\$phase" == 'foreground' ]]; then
            saw_foreground=1
            background_polls=0
        elif [[ "\$saw_foreground" -eq 1 ]]; then
            background_polls=\$((background_polls + 1))
            if [[ "\$background_polls" -ge "\$BACKGROUND_POLLS_TO_KILL" ]]; then
                kill -TERM "\$pid" > /dev/null 2>&1 || true
                for _ in {1..5}; do
                    if ! kill -0 "\$pid" > /dev/null 2>&1; then
                        return 0
                    fi
                    sleep 1
                done
                kill -KILL "\$pid" > /dev/null 2>&1 || true
                return 0
            fi
        fi

        sleep "\$POLL_INTERVAL"
    done
}

wait_for_launched_pid() {
    local pid

    for _ in {1..30}; do
        pid=\$(pgrep -f "\$APP_EXEC" | tail -n1 || true)
        if [[ -n "\$pid" ]]; then
            printf '%s\n' "\$pid"
            return 0
        fi
        sleep 1
    done

    return 1
}

if [[ "\${1:-}" == "--watch" && -n "\${2:-}" ]]; then
    watch_for_lingering_process "\$2"
    exit 0
fi

if pgrep -x "\$APP_NAME" > /dev/null 2>&1 || pgrep -f "\$APP_EXEC" > /dev/null 2>&1; then
    pkill -TERM -x "\$APP_NAME" > /dev/null 2>&1 || true
    pkill -TERM -f "\$APP_EXEC" > /dev/null 2>&1 || true
    for _ in {1..5}; do
        if ! pgrep -x "\$APP_NAME" > /dev/null 2>&1 && ! pgrep -f "\$APP_EXEC" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    pkill -KILL -x "\$APP_NAME" > /dev/null 2>&1 || true
    pkill -KILL -f "\$APP_EXEC" > /dev/null 2>&1 || true
    sleep 1
fi

if [[ -d "\$APP_BUNDLE" ]]; then
    /usr/bin/open "\$APP_BUNDLE" --args -ApplePersistenceIgnoreState YES
    APP_PID=\$(wait_for_launched_pid || true)
    if [[ -n "\$APP_PID" ]]; then
        nohup "\$0" --watch "\$APP_PID" > /dev/null 2>&1 &
        disown
    fi
    exit 0
fi

exec /usr/bin/open -a '/Applications/PlayCover.app' 'playcoverapp://app?action=open&bundleId=com.mojang.minecraftpe'
EOF

    chmod 755 "${launcher_bin}"
}

echo "Applying Minecraft working state..."

if [ ! -d "${PLAYCOVER_APP}" ]; then
    echo "Missing ${PLAYCOVER_APP}. Install PlayCover.app from the DMG first."
    exit 1
fi

if [ ! -d "${SNAPSHOT_DIR}" ]; then
    echo "Missing working-state payload at ${SNAPSHOT_DIR}."
    exit 1
fi

MC_APP="$(wait_for_minecraft_app_ready || true)"
MC_LAUNCHER="$(find_minecraft_launcher || true)"

if [ -z "${MC_APP}" ]; then
    echo "Missing Minecraft app inside ${PLAYCOVER_APPS_DIR}."
    echo "Import/install Minecraft in PlayCover first, then run this script again."
    exit 1
fi

mkdir -p "${HOME}/Library/Frameworks"
rm -rf "${PLAYTOOLS_USER}"
ditto "${PLAYTOOLS_EMBEDDED}" "${PLAYTOOLS_USER}"

mkdir -p "${PLAYCOVER_SETTINGS_DIR}"
cp "${SNAPSHOT_DIR}/playcover-settings-minecraft.plist" \
   "${PLAYCOVER_SETTINGS_DIR}/com.mojang.minecraftpe.plist"

if [ -n "${MC_LAUNCHER}" ] && [ -d "${MC_LAUNCHER}" ]; then
    mkdir -p "${MC_LAUNCHER}/Contents/MacOS"
    write_launcher_script "${MC_LAUNCHER}/Contents/MacOS/launcher" "${MC_APP}/minecraftpe"
    codesign --force --deep --sign - "${MC_LAUNCHER}"
else
    echo "Minecraft launcher app not found yet; skipping launcher overlay."
fi

codesign --force --deep --sign - "${PLAYTOOLS_USER}"
codesign --force --deep --sign - "${PLAYCOVER_APP}"

MC_APP="$(wait_for_minecraft_app_ready || true)"
if [ -z "${MC_APP}" ]; then
    echo "Minecraft app disappeared before final codesign."
    echo "Wait a few seconds for import to finish, then rerun the script."
    exit 1
fi

if [ -s "${SNAPSHOT_DIR}/minecraft-entitlements.template.plist" ]; then
    TEMP_ENTITLEMENTS="$(mktemp "${TMPDIR:-/tmp}/minecraft-entitlements.XXXXXX.plist")"
    sed "s#__HOME__#${HOME}#g" \
      "${SNAPSHOT_DIR}/minecraft-entitlements.template.plist" \
      > "${TEMP_ENTITLEMENTS}"
    codesign --force --deep --sign - \
      --entitlements "${TEMP_ENTITLEMENTS}" \
      "${MC_APP}"
else
    codesign --force --deep --sign - "${MC_APP}"
fi

echo
echo "Done."
echo "Minecraft app path: ${MC_APP}"
echo "Direct launch:"
echo "  \"${MC_APP}/minecraftpe\""
