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
MAC_ARCH="${MAC_ARCH:-universal}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.temporary/macos-deploy}"
AUDIO_SOURCE_DIR="${AUDIO_SOURCE_DIR:-$ROOT_DIR/audio-files}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-20}"

if [[ -n "${HOME:-}" ]]; then
    DEFAULT_INSTALL_PATH="$HOME/Applications/$APP_NAME.app"
else
    DEFAULT_INSTALL_PATH="$ROOT_DIR/.temporary/Applications/$APP_NAME.app"
fi
INSTALL_PATH="${INSTALL_PATH:-$DEFAULT_INSTALL_PATH}"
SCRIPT_NAME="${DEPLOY_SCRIPT_NAME:-$(basename "${BASH_SOURCE[0]}")}"

APP_MIN_MACOS_VERSION="13.0"
WIDGET_MIN_MACOS_VERSION="14.0"

LAUNCH_AFTER_INSTALL=1
BUILD_ONLY=0

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Builds, installs, launches, and verifies AmbientSpace as a Mac Catalyst app.

Options:
  --bundle-id ID          Bundle identifier for this local build
  --configuration NAME    Xcode configuration. Default: $CONFIGURATION
  --audio-source PATH     Local audio source directory. Default: $AUDIO_SOURCE_DIR
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
  MAC_ARCH                Catalyst architecture or universal. Default: $MAC_ARCH
  DERIVED_DATA_PATH       Same as --derived-data
  AUDIO_SOURCE_DIR        Same as --audio-source. The directory is read-only input.
  INSTALL_PATH            Same as --install-path
  LAUNCH_TIMEOUT_SECONDS  Launch verification timeout. Default: $LAUNCH_TIMEOUT_SECONDS

Examples:
  BUNDLE_ID=com.example.ambientspace bash scripts/deploy_macos.example.sh
  AUDIO_SOURCE_DIR=/path/to/audio-files \\
    bash scripts/deploy_macos.example.sh --build-only
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
            --audio-source)
                [[ $# -ge 2 && -n "$2" ]] || fail "--audio-source requires a directory."
                AUDIO_SOURCE_DIR="$2"
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
    [[ -d "$AUDIO_SOURCE_DIR" ]] || fail "Audio source directory not found: $AUDIO_SOURCE_DIR. Pass --audio-source PATH or set AUDIO_SOURCE_DIR."
    AUDIO_SOURCE_DIR="$(cd "$AUDIO_SOURCE_DIR" && pwd -P)"
    [[ -n "$BUNDLE_ID" && "$BUNDLE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || \
        fail "BUNDLE_ID must contain only letters, numbers, dots, and hyphens."
    [[ "$CODE_SIGNING_ALLOWED" == "YES" || "$CODE_SIGNING_ALLOWED" == "NO" ]] || \
        fail "CODE_SIGNING_ALLOWED must be YES or NO."
    [[ "$MAC_ARCH" == "universal" || "$MAC_ARCH" == "arm64" || "$MAC_ARCH" == "x86_64" ]] || \
        fail "MAC_ARCH must be universal, arm64, or x86_64."
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
        -sdk macosx
        -derivedDataPath "$DERIVED_DATA_PATH"
        "CODE_SIGNING_ALLOWED=$CODE_SIGNING_ALLOWED"
        "AMBIENTSPACE_BUNDLE_ID=$BUNDLE_ID"
        "AMBIENTSPACE_AUDIO_SOURCE_DIR=$AUDIO_SOURCE_DIR"
    )

    if [[ "$MAC_ARCH" == "universal" ]]; then
        build_arguments+=(
            -destination "platform=macOS,variant=Mac Catalyst"
            "ARCHS=x86_64 arm64"
        )
    else
        build_arguments+=(
            -destination "platform=macOS,arch=$MAC_ARCH,variant=Mac Catalyst"
            "ARCHS=$MAC_ARCH"
        )
    fi
    build_arguments+=("ONLY_ACTIVE_ARCH=NO")

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

read_bundle_executable() {
    local bundle_path="$1"
    plutil -extract CFBundleExecutable raw -o - "$bundle_path/Contents/Info.plist"
}

read_minimum_system_version() {
    local bundle_path="$1"
    plutil -extract LSMinimumSystemVersion raw -o - "$bundle_path/Contents/Info.plist"
}

validate_architectures() {
    local executable_path="$1"
    local bundle_name="$2"
    local actual_architectures
    actual_architectures="$(lipo -archs "$executable_path")" || \
        fail "Could not inspect architectures for $bundle_name."

    if [[ "$MAC_ARCH" == "universal" ]]; then
        [[ " $actual_architectures " == *" x86_64 "* ]] || \
            fail "$bundle_name does not contain x86_64 (found: $actual_architectures)."
        [[ " $actual_architectures " == *" arm64 "* || " $actual_architectures " == *" arm64e "* ]] || \
            fail "$bundle_name does not contain arm64 (found: $actual_architectures)."
    elif [[ "$actual_architectures" != *"$MAC_ARCH"* ]]; then
        fail "$bundle_name does not contain $MAC_ARCH (found: $actual_architectures)."
    fi

    echo "$bundle_name architectures: $actual_architectures"
}

validate_bundle_metadata() {
    local bundle_path="$1"
    local expected_bundle_id="$2"
    local expected_minimum_system_version="$3"
    local bundle_name="$4"

    [[ -f "$bundle_path/Contents/Info.plist" ]] || \
        fail "$bundle_name has no Info.plist."

    local bundle_id
    bundle_id="$(read_bundle_identifier "$bundle_path")" || \
        fail "Could not read the $bundle_name bundle identifier."
    [[ "$bundle_id" == "$expected_bundle_id" ]] || \
        fail "$bundle_name bundle identifier is '$bundle_id'; expected '$expected_bundle_id'."

    local minimum_system_version
    minimum_system_version="$(read_minimum_system_version "$bundle_path")" || \
        fail "Could not read the $bundle_name minimum system version."
    [[ "$minimum_system_version" == "$expected_minimum_system_version" ]] || \
        fail "$bundle_name requires macOS $minimum_system_version; expected macOS $expected_minimum_system_version."

    local executable_name
    executable_name="$(read_bundle_executable "$bundle_path")" || \
        fail "Could not read the $bundle_name executable name."
    local executable_path="$bundle_path/Contents/MacOS/$executable_name"
    [[ -f "$executable_path" ]] || \
        fail "$bundle_name executable was not found at Contents/MacOS/$executable_name."
    validate_architectures "$executable_path" "$bundle_name"
}

validate_built_app() {
    [[ -d "$APP_PATH" ]] || fail "Build succeeded but the app was not found at: $APP_PATH"
    [[ -f "$APP_PATH/Contents/Info.plist" ]] || fail "Built app has no Info.plist."

    require_command lipo
    validate_bundle_metadata "$APP_PATH" "$BUNDLE_ID" "$APP_MIN_MACOS_VERSION" "AmbientSpace.app"

    local widget_path="$APP_PATH/Contents/PlugIns/AmbientSpaceWidgets.appex"
    [[ -d "$widget_path" ]] || fail "Built app has no AmbientSpaceWidgets extension."
    validate_bundle_metadata "$widget_path" "$BUNDLE_ID.Widgets" "$WIDGET_MIN_MACOS_VERSION" "AmbientSpaceWidgets.appex"

    if [[ "$CODE_SIGNING_ALLOWED" == "YES" ]]; then
        require_command codesign
        codesign --verify --deep --strict "$APP_PATH" || \
            fail "The signed Catalyst app failed codesign verification."
    fi

    echo "Validated $APP_PATH"
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

exercise_interaction() {
    require_command osascript

    local interaction_script
    interaction_script='tell application "System Events" to tell process "AmbientSpace" to click (first UI element of window 1 whose value of attribute "AXIdentifier" starts with "trackRow-")'

    echo "Exercising the AmbientSpace playback row..."
    local attempt
    local interaction_error=""
    for ((attempt = 1; attempt <= LAUNCH_TIMEOUT_SECONDS; attempt++)); do
        if interaction_error="$(osascript -e "$interaction_script" 2>&1)"; then
            echo "Interaction verified: a playback row accepted a click."
            return
        fi
        sleep 1
    done

    fail "The app launched, but the playback row interaction could not be verified. Grant Accessibility access to your terminal under System Settings > Privacy & Security > Accessibility, or use --no-launch. Last error: $interaction_error"
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
        exercise_interaction
    else
        echo "Launch skipped (--no-launch)."
    fi

    echo "AmbientSpace was deployed successfully on this Mac."
}

main "$@"
