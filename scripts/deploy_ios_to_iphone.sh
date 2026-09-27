#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ios-app/AmbientSpace.xcodeproj"
SCHEME="AmbientSpace"
APP_NAME="AmbientSpace"
BUNDLE_ID="${BUNDLE_ID:-com.florisvandesande.AmbientSpace}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/AmbientSpaceDeviceBuild}"
POST_INSTALL_TIMEOUT_SECONDS="${POST_INSTALL_TIMEOUT_SECONDS:-20}"
POST_INSTALL_RETRIES="${POST_INSTALL_RETRIES:-2}"
DEVICE_ID=""
LIST_ONLY=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [device-id]

Builds, installs, launches, and verifies AmbientSpace on a physical iPhone.

Options:
  --device ID            Explicit device identifier from devicectl
  --configuration NAME   Xcode build configuration. Default: $CONFIGURATION
  --team ID              Your Apple Developer team identifier (required)
  --list                 Show paired physical iPhones and exit
  -h, --help             Show this help message

Environment variables:
  DEVELOPMENT_TEAM       Alternative to --team; no personal team is stored here
  BUNDLE_ID              Bundle identifier for your copy. Default: $BUNDLE_ID
  DERIVED_DATA_PATH      Xcode build directory. Default: $DERIVED_DATA_PATH
EOF
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "Required command not found: $1"
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --device)
                [[ $# -ge 2 ]] || fail "--device requires an identifier."
                DEVICE_ID="$2"
                shift 2
                ;;
            --configuration)
                [[ $# -ge 2 ]] || fail "--configuration requires a name."
                CONFIGURATION="$2"
                shift 2
                ;;
            --team)
                [[ $# -ge 2 && -n "$2" ]] || fail "--team requires an identifier."
                DEVELOPMENT_TEAM="$2"
                shift 2
                ;;
            --list)
                LIST_ONLY=1
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
                if [[ -n "$DEVICE_ID" ]]; then
                    fail "Only one device identifier can be provided."
                fi
                DEVICE_ID="$1"
                shift
                ;;
        esac
    done
}

write_devices_json() {
    local output_path="$1"
    xcrun devicectl list devices --json-output "$output_path" >/dev/null
}

list_iphones() {
    local devices_json
    devices_json="$(mktemp "${TMPDIR:-/tmp}/ambientspace-devices.XXXXXX")"
    write_devices_json "$devices_json"

    python3 - "$devices_json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
devices = payload.get("result", {}).get("devices", [])

found = False
for device in devices:
    hardware = device.get("hardwareProperties", {})
    product_type = hardware.get("productType", "")
    if not product_type.startswith("iPhone") or hardware.get("reality") != "physical":
        continue

    identifier = device.get("identifier", "")
    properties = device.get("deviceProperties", {})
    connection = device.get("connectionProperties", {})
    name = properties.get("name", "Unnamed iPhone")
    state = connection.get("tunnelState") or connection.get("state") or device.get("state", "unknown")
    print(f"{name}\t{identifier}\t{state}\t{product_type}")
    found = True

if not found:
    print("No paired physical iPhones found.")
PY

    rm -f "$devices_json"
}

select_first_iphone() {
    local devices_json
    devices_json="$(mktemp "${TMPDIR:-/tmp}/ambientspace-devices.XXXXXX")"
    write_devices_json "$devices_json"

    DEVICE_ID="$(python3 - "$devices_json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
devices = payload.get("result", {}).get("devices", [])

iphones = [
    device
    for device in devices
    if device.get("hardwareProperties", {}).get("productType", "").startswith("iPhone")
    and device.get("hardwareProperties", {}).get("reality") == "physical"
    and device.get("identifier")
]

available = [
    device
    for device in iphones
    if (device.get("connectionProperties", {}).get("tunnelState") or device.get("connectionProperties", {}).get("state") or device.get("state", "")).lower()
    in {"available", "connected"}
]

selected = (available or iphones)
if len(selected) > 1:
    print("More than one iPhone is available. Use --list, then --device ID to choose one.", file=sys.stderr)
    sys.exit(1)
if selected:
    print(selected[0]["identifier"])
PY
)"

    rm -f "$devices_json"

    if [[ -z "$DEVICE_ID" ]]; then
        fail "No physical iPhone found. Connect and unlock an iPhone, trust this Mac, then run the script again."
    fi
}

validate_selected_iphone() {
    local devices_json
    local validation_error
    devices_json="$(mktemp "${TMPDIR:-/tmp}/ambientspace-devices.XXXXXX")"
    write_devices_json "$devices_json"

    if ! validation_error="$(python3 - "$devices_json" "$DEVICE_ID" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
device_id = sys.argv[2]
devices = payload.get("result", {}).get("devices", [])
device = next((item for item in devices if item.get("identifier") == device_id), None)

if device is None:
    print(f"No device found with identifier '{device_id}'. Run --list to show physical iPhones.")
    sys.exit(1)

hardware = device.get("hardwareProperties", {})
properties = device.get("deviceProperties", {})
connection = device.get("connectionProperties", {})
name = properties.get("name", "Unnamed device")

if not hardware.get("productType", "").startswith("iPhone"):
    print(f"'{name}' is not an iPhone. Run --list to show physical iPhones.")
    sys.exit(1)

if hardware.get("reality") != "physical":
    print(f"'{name}' is a simulator. Select a physical iPhone shown by --list.")
    sys.exit(1)

state = (connection.get("tunnelState") or connection.get("state") or device.get("state", "")).lower()
if state not in {"available", "connected"}:
    print(f"Physical iPhone '{name}' is not connected. Unlock it and connect it by cable or paired Wi-Fi.")
    sys.exit(1)
PY
)"; then
        rm -f "$devices_json"
        fail "$validation_error"
    fi

    rm -f "$devices_json"
}

run_devicectl_with_timeout() {
    local timeout_seconds="$1"
    shift

    xcrun devicectl "$@" &
    local command_pid=$!
    local elapsed=0

    while kill -0 "$command_pid" >/dev/null 2>&1; do
        if [[ "$elapsed" -ge "$timeout_seconds" ]]; then
            kill -TERM "$command_pid" >/dev/null 2>&1 || true
            sleep 1
            kill -KILL "$command_pid" >/dev/null 2>&1 || true
            wait "$command_pid" >/dev/null 2>&1 || true
            return 124
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    wait "$command_pid"
}

run_post_install_step() {
    local label="$1"
    shift
    local attempt=1
    local exit_code=0

    while [[ "$attempt" -le "$POST_INSTALL_RETRIES" ]]; do
        if run_devicectl_with_timeout "$POST_INSTALL_TIMEOUT_SECONDS" "$@"; then
            return 0
        else
            exit_code=$?
        fi

        if [[ "$attempt" -lt "$POST_INSTALL_RETRIES" ]]; then
            echo "$label did not complete; retrying ($attempt/$POST_INSTALL_RETRIES)..." >&2
        fi
        attempt=$((attempt + 1))
    done

    if [[ "$exit_code" -eq 124 ]]; then
        echo "$label timed out after $POST_INSTALL_TIMEOUT_SECONDS seconds." >&2
    else
        echo "$label failed with exit code $exit_code." >&2
    fi
    return "$exit_code"
}

validate_built_app() {
    local app_path="$1"
    local built_bundle_id

    [[ -d "$app_path" ]] || fail "Build completed, but the app was not found at: $app_path"

    built_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
    if [[ "$built_bundle_id" != "$BUNDLE_ID" ]]; then
        fail "Built bundle identifier is '$built_bundle_id'; expected '$BUNDLE_ID'."
    fi

    if [[ ! -f "$app_path/embedded.mobileprovision" ]]; then
        fail "The app has no embedded development provisioning profile. Check the Apple Developer team and signing settings."
    fi

    codesign --verify --deep --strict "$app_path"
}

main() {
    parse_arguments "$@"

    require_command xcrun
    require_command xcodebuild
    require_command python3
    require_command codesign

    [[ -d "$PROJECT_PATH" ]] || fail "Xcode project not found at: $PROJECT_PATH"

    if [[ "$LIST_ONLY" -eq 1 ]]; then
        list_iphones
        exit 0
    fi

    if [[ -z "$DEVICE_ID" ]]; then
        select_first_iphone
    fi
    validate_selected_iphone

    if [[ -z "$DEVELOPMENT_TEAM" ]]; then
        fail "No signing team selected. Run: $0 --team YOUR_TEAM_ID --device $DEVICE_ID"
    fi
    [[ "$CONFIGURATION" == "Debug" || "$CONFIGURATION" == "Release" ]] || fail "Use Debug or Release for --configuration."
    [[ "$POST_INSTALL_RETRIES" =~ ^[1-9][0-9]*$ ]] || fail "POST_INSTALL_RETRIES must be a positive integer."
    [[ "$POST_INSTALL_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || fail "POST_INSTALL_TIMEOUT_SECONDS must be a positive integer."

    local app_path="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/${APP_NAME}.app"

    echo "Building $APP_NAME for iPhone with team $DEVELOPMENT_TEAM..."
    xcodebuild build \
        -quiet \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -allowProvisioningUpdates \
        -allowProvisioningDeviceRegistration \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"

    validate_built_app "$app_path"

    echo "Installing $APP_NAME on iPhone device: $DEVICE_ID"
    xcrun devicectl device install app \
        --device "$DEVICE_ID" \
        "$app_path"

    echo "Launching $BUNDLE_ID..."
    local launch_succeeded=1
    if ! run_post_install_step "Launch" device process launch \
        --device "$DEVICE_ID" \
        --terminate-existing \
        "$BUNDLE_ID"; then
        echo "The app was installed, but could not be launched automatically." >&2
        echo "Unlock the iPhone and open AmbientSpace manually." >&2
        launch_succeeded=0
    fi

    echo "Verifying installation..."
    run_post_install_step "Verification" device info apps \
        --device "$DEVICE_ID" \
        --bundle-id "$BUNDLE_ID" || fail "Installed the app, but could not verify it on the device."

    [[ "$launch_succeeded" -eq 1 ]] || fail "Installed the app, but automatic launch failed."
    echo "AmbientSpace was installed, launched, and verified successfully."
}

main "$@"
