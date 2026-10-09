#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ios-app/AmbientSpace.xcodeproj"
SCHEME="AmbientSpace"
APP_NAME="AmbientSpace"
BUNDLE_ID="${BUNDLE_ID:-com.example.AmbientSpace}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"
MAC_ARCH="${MAC_ARCH:-$(uname -m)}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.temporary/macos-deploy}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-20}"

if [[ -n "${HOME:-}" ]]; then
    DEFAULT_INSTALL_PATH="$HOME/Applications/$APP_NAME.app"
else
    DEFAULT_INSTALL_PATH="$ROOT_DIR/.temporary/Applications/$APP_NAME.app"
fi
INSTALL_PATH="${INSTALL_PATH:-$DEFAULT_INSTALL_PATH}"
SCRIPT_NAME="${DEPLOY_SCRIPT_NAME:-$(basename "${BASH_SOURCE[0]}")}"

LAUNCH_AFTER_INSTALL=1
BUILD_ONLY=0

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Builds, installs, launches, and verifies AmbientSpace as a Mac Catalyst app.

Options:
  --bundle-id ID          Bundle identifier for this local build
  --configuration NAME    Xcode configuration. Default: $CONFIGURATION
  --derived-data PATH     Xcode build directory. Default: $DERIVED_DATA_PATH
  --install-path PATH     Destination .app path. Default: $INSTALL_PATH
  --team ID               Use this Apple Developer team and enable signing
  --signed                Enable Xcode signing for this build
  --unsigned              Disable signing. Default: $CODE_SIGNING_ALLOWED
  --build-only            Build and validate without installing or launching
  --no-launch             Install and verify without launching
  -h, --help              Show this help message

Environment variables:
  BUNDLE_ID               Same as --bundle-id
  CONFIGURATION           Same as --configuration
  DEVELOPMENT_TEAM        Signing-team override; never commit a personal value
  CODE_SIGNING_ALLOWED    YES or NO. Default: $CODE_SIGNING_ALLOWED
  MAC_ARCH                Catalyst architecture. Default: $MAC_ARCH
  DERIVED_DATA_PATH       Same as --derived-data
  INSTALL_PATH            Same as --install-path
  LAUNCH_TIMEOUT_SECONDS  Launch verification timeout. Default: $LAUNCH_TIMEOUT_SECONDS

Examples:
  BUNDLE_ID=com.example.ambientspace bash scripts/deploy_macos.example.sh
  INSTALL_PATH="\$HOME/Applications/AmbientSpace.app" \\
    bash scripts/deploy_macos.example.sh --build-only
  bash scripts/deploy_macos.example.sh --signed --team TEAM_ID
EOF
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --bundle-id)
                [[ $# -ge 2 && -n "$2" ]] || fail "--bundle-id requires an identifier."
                BUNDLE_ID="$2"
                shift 2
                ;;
            --configuration)
                [[ $# -ge 2 && -n "$2" ]] || fail "--configuration requires a name."
                CONFIGURATION="$2"
                shift 2
                ;;
            --derived-data)
                [[ $# -ge 2 && -n "$2" ]] || fail "--derived-data requires a path."
                DERIVED_DATA_PATH="$2"
                shift 2
                ;;
            --install-path)
                [[ $# -ge 2 && -n "$2" ]] || fail "--install-path requires a .app path."
                INSTALL_PATH="$2"
                shift 2
                ;;
            --team)
                [[ $# -ge 2 && -n "$2" ]] || fail "--team requires an identifier."
                DEVELOPMENT_TEAM="$2"
                CODE_SIGNING_ALLOWED="YES"
                shift 2
                ;;
            --signed)
                CODE_SIGNING_ALLOWED="YES"
                shift
                ;;
            --unsigned)
                CODE_SIGNING_ALLOWED="NO"
                shift
                ;;
            --build-only)
                BUILD_ONLY=1
                shift
                ;;
            --no-launch)
                LAUNCH_AFTER_INSTALL=0
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --*)
                fail "Unknown option: $1"
                ;;
            *)
                fail "Unexpected argument: $1"
                ;;
        esac
    done
}

validate_configuration() {
    [[ -d "$PROJECT_PATH" ]] || fail "Xcode project not found at: $PROJECT_PATH"
    [[ -n "$BUNDLE_ID" && "$BUNDLE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || \
        fail "BUNDLE_ID must contain only letters, numbers, dots, and hyphens."
    [[ "$CODE_SIGNING_ALLOWED" == "YES" || "$CODE_SIGNING_ALLOWED" == "NO" ]] || \
        fail "CODE_SIGNING_ALLOWED must be YES or NO."
    [[ "$MAC_ARCH" == "arm64" || "$MAC_ARCH" == "x86_64" ]] || \
        fail "MAC_ARCH must be arm64 or x86_64."
    [[ "$INSTALL_PATH" == *.app ]] || fail "INSTALL_PATH must end in .app."
    [[ "$LAUNCH_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || \
        fail "LAUNCH_TIMEOUT_SECONDS must be a positive integer."
}

build_app() {
    mkdir -p "$DERIVED_DATA_PATH"

    local -a build_arguments=(
        build
        -quiet
        -project "$PROJECT_PATH"
        -scheme "$SCHEME"
        -configuration "$CONFIGURATION"
        -destination "platform=macOS,arch=$MAC_ARCH,variant=Mac Catalyst"
        -derivedDataPath "$DERIVED_DATA_PATH"
        "CODE_SIGNING_ALLOWED=$CODE_SIGNING_ALLOWED"
        "AMBIENTSPACE_BUNDLE_ID=$BUNDLE_ID"
    )

    if [[ -n "$DEVELOPMENT_TEAM" ]]; then
        build_arguments+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
    fi

    echo "Building $APP_NAME for Mac Catalyst ($CONFIGURATION)..."
    xcodebuild "${build_arguments[@]}"

    APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-maccatalyst/$APP_NAME.app"
}

read_bundle_identifier() {
    local app_path="$1"
    plutil -extract CFBundleIdentifier raw -o - "$app_path/Contents/Info.plist"
}

validate_built_app() {
    [[ -d "$APP_PATH" ]] || fail "Build succeeded but the app was not found at: $APP_PATH"
    [[ -f "$APP_PATH/Contents/Info.plist" ]] || fail "Built app has no Info.plist."

    local built_bundle_id
    built_bundle_id="$(read_bundle_identifier "$APP_PATH")" || fail "Could not read the built bundle identifier."
    [[ "$built_bundle_id" == "$BUNDLE_ID" ]] || \
        fail "Built bundle identifier is '$built_bundle_id'; expected '$BUNDLE_ID'."

    local widget_path="$APP_PATH/Contents/PlugIns/AmbientSpaceWidgets.appex"
    [[ -d "$widget_path" ]] || fail "Built app has no AmbientSpaceWidgets extension."

    if [[ "$CODE_SIGNING_ALLOWED" == "YES" ]]; then
        require_command codesign
        codesign --verify --deep --strict "$APP_PATH" || \
            fail "The signed Catalyst app failed codesign verification."
    fi

    echo "Validated $APP_PATH"
    echo "Bundle identifier: $built_bundle_id"
    echo "Widget extension: $widget_path"
}

install_app() {
    local install_parent
    install_parent="$(dirname "$INSTALL_PATH")"
    mkdir -p "$install_parent" || \
        fail "Could not create '$install_parent'. Use --install-path in a writable directory."
    [[ -w "$install_parent" ]] || \
        fail "Install directory is not writable: $install_parent. Use --install-path in a writable directory."

    local staging_root
    staging_root="$(mktemp -d "${TMPDIR:-/tmp}/ambientspace-macos-deploy.XXXXXX")"
    local staged_app="$staging_root/$APP_NAME.app"
    ditto "$APP_PATH" "$staged_app"

    local backup_path=""
    if [[ -e "$INSTALL_PATH" ]]; then
        backup_path="$INSTALL_PATH.previous.$(date +%Y%m%d-%H%M%S)-$$"
        mv "$INSTALL_PATH" "$backup_path" || {
            rm -rf "$staging_root"
            fail "Could not move the existing app aside: $INSTALL_PATH"
        }
    fi

    if ! mv "$staged_app" "$INSTALL_PATH"; then
        if [[ -n "$backup_path" && -e "$backup_path" ]]; then
            mv "$backup_path" "$INSTALL_PATH" || true
        fi
        rm -rf "$staging_root"
        fail "Could not install the app at: $INSTALL_PATH"
    fi
    rm -rf "$staging_root"

    if [[ -n "$backup_path" ]]; then
        echo "Previous app preserved at: $backup_path"
    fi
    echo "Installed: $INSTALL_PATH"
}

stop_running_app() {
    if ! pgrep -f "Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
        return
    fi

    require_command osascript
    echo "Closing the running $APP_NAME before replacing it..."
    osascript -e "tell application \"$APP_NAME\" to quit" || \
        fail "Could not ask the running $APP_NAME to quit."

    local attempt
    for ((attempt = 1; attempt <= LAUNCH_TIMEOUT_SECONDS; attempt++)); do
        if ! pgrep -f "Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
            return
        fi
        sleep 1
    done

    fail "The running $APP_NAME did not quit within ${LAUNCH_TIMEOUT_SECONDS}s; the existing app was not replaced."
}

verify_installed_app() {
    [[ -d "$INSTALL_PATH" ]] || fail "Installed app not found at: $INSTALL_PATH"
    local installed_bundle_id
    installed_bundle_id="$(read_bundle_identifier "$INSTALL_PATH")" || \
        fail "Could not read the installed bundle identifier."
    [[ "$installed_bundle_id" == "$BUNDLE_ID" ]] || \
        fail "Installed bundle identifier is '$installed_bundle_id'; expected '$BUNDLE_ID'."
    [[ -d "$INSTALL_PATH/Contents/PlugIns/AmbientSpaceWidgets.appex" ]] || \
        fail "Installed app is missing AmbientSpaceWidgets.appex."
    echo "Verified installed bundle: $installed_bundle_id"
}

launch_and_verify() {
    echo "Launching $INSTALL_PATH..."
    open "$INSTALL_PATH"

    local attempt
    for ((attempt = 1; attempt <= LAUNCH_TIMEOUT_SECONDS; attempt++)); do
        if pgrep -f "Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
            echo "Launch verified: $APP_NAME is running."
            return
        fi
        sleep 1
    done

    fail "The app was installed, but no running $APP_NAME process was detected within ${LAUNCH_TIMEOUT_SECONDS}s."
}

main() {
    parse_arguments "$@"

    require_command ditto
    require_command mktemp
    require_command open
    require_command plutil
    require_command pgrep
    require_command xcodebuild
    validate_configuration

    build_app
    validate_built_app

    if [[ "$BUILD_ONLY" -eq 1 ]]; then
        echo "Build-only deployment completed successfully."
        exit 0
    fi

    stop_running_app
    install_app
    verify_installed_app

    if [[ "$LAUNCH_AFTER_INSTALL" -eq 1 ]]; then
        launch_and_verify
    else
        echo "Launch skipped (--no-launch)."
    fi

    echo "AmbientSpace was deployed successfully on this Mac."
}

main "$@"
