#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLAYCOVER_APP="/Applications/PlayCover.app"
PLAYCOVER_APPS_DIR="${HOME}/Library/Containers/io.playcover.PlayCover/Applications"
PLAYCOVER_LAUNCHERS_DIR="${HOME}/Applications/PlayCover"
POLL_INTERVAL=2
IMPORT_TIMEOUT=180
STABLE_POLLS_REQUIRED=3

APPLY_SCRIPT_CANDIDATES="${BASE_DIR}/apply-minecraft-working-state.sh or ${BASE_DIR}/Extras/apply-minecraft-working-state.sh"

if [ -x "${BASE_DIR}/apply-minecraft-working-state.sh" ]; then
    APPLY_SCRIPT="${BASE_DIR}/apply-minecraft-working-state.sh"
elif [ -x "${BASE_DIR}/Extras/apply-minecraft-working-state.sh" ]; then
    APPLY_SCRIPT="${BASE_DIR}/Extras/apply-minecraft-working-state.sh"
else
    APPLY_SCRIPT=""
fi

usage() {
    cat <<EOF
Usage:
  $(basename "$0") [path/to/Minecraft.ipa]

If no IPA path is provided and Minecraft is not installed yet,
the script will prompt you to choose an IPA file.

What it does:
1. Opens the IPA with /Applications/PlayCover.app
2. Waits for Minecraft to finish importing
3. Applies the verified Minecraft working-state overlay
EOF
}

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
        "${PLAYCOVER_LAUNCHERS_DIR}/Minecraft.app" \
        "${PLAYCOVER_LAUNCHERS_DIR}/com.mojang.minecraftpe.app"
    do
        if [ -d "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

choose_ipa_interactively() {
    osascript <<'OSA'
try
    POSIX path of (choose file with prompt "Select your Minecraft IPA for PlayCover" of type {"ipa"})
on error number -128
    return ""
end try
OSA
}

wait_for_minecraft_import() {
    elapsed=0
    saw_app=0
    stable_polls=0
    last_path=""

    while [ "${elapsed}" -lt "${IMPORT_TIMEOUT}" ]; do
        if MC_APP="$(find_minecraft_app 2>/dev/null)"; then
            saw_app=1

            if [ -f "${MC_APP}/Info.plist" ] && [ -x "${MC_APP}/minecraftpe" ]; then
                if [ "${MC_APP}" = "${last_path}" ]; then
                    stable_polls=$((stable_polls + 1))
                else
                    stable_polls=1
                    last_path="${MC_APP}"
                fi
            else
                stable_polls=0
                last_path=""
            fi

            if find_minecraft_launcher >/dev/null 2>&1 && [ "${stable_polls}" -ge "${STABLE_POLLS_REQUIRED}" ]; then
                return 0
            fi
        else
            stable_polls=0
            last_path=""
        fi

        sleep "${POLL_INTERVAL}"
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    if [ "${saw_app}" -eq 1 ] && [ "${stable_polls}" -ge "${STABLE_POLLS_REQUIRED}" ]; then
        return 0
    fi

    return 1
}

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi

if [ ! -d "${PLAYCOVER_APP}" ]; then
    echo "Missing ${PLAYCOVER_APP}. Install PlayCover.app first."
    exit 1
fi

if [ -z "${APPLY_SCRIPT}" ]; then
    echo "Missing helper: ${APPLY_SCRIPT_CANDIDATES}"
    exit 1
fi

IPA_PATH="${1:-}"
MC_APP="$(find_minecraft_app || true)"

if [ -z "${IPA_PATH}" ] && [ -z "${MC_APP}" ]; then
    IPA_PATH="$(choose_ipa_interactively | tr -d '\r')"
fi

if [ -n "${IPA_PATH}" ]; then
    if [ ! -f "${IPA_PATH}" ]; then
        echo "IPA not found: ${IPA_PATH}"
        exit 1
    fi

    case "${IPA_PATH}" in
        *.ipa|*.IPA) ;;
        *)
            echo "Expected an .ipa file, got: ${IPA_PATH}"
            exit 1
            ;;
    esac

    echo "Opening IPA in PlayCover:"
    echo "  ${IPA_PATH}"
    /usr/bin/open -a "${PLAYCOVER_APP}" "${IPA_PATH}"

    echo "Waiting for Minecraft to finish importing into PlayCover..."
    if ! wait_for_minecraft_import; then
        echo "Timed out waiting for Minecraft to appear in PlayCover."
        echo "If the import is still running, wait for it to finish and rerun this script."
        exit 1
    fi
else
    if [ -z "${MC_APP}" ]; then
        echo "Minecraft is not installed yet."
        echo "Run this script with a Minecraft IPA, or select one when prompted."
        exit 1
    fi

    echo "Minecraft is already installed in PlayCover:"
    echo "  ${MC_APP}"
    echo "Skipping IPA import and reapplying the verified working state."
fi

echo "Applying verified Minecraft working state..."
exec "${APPLY_SCRIPT}"
