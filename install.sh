#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGROK="$ROOT_DIR/ngrok"

if [[ "${PREFIX:-}" != *"com.termux"* ]]; then
    printf 'This installer must be run inside Termux.\n' >&2
    exit 1
fi

printf '%s\n' 'Installing Termux MCP requirements...'
pkg update -y
pkg install -y python proot resolv-conf curl unzip

# Termux manages pip through its own package manager. Upgrading pip with pip
# itself is forbidden because it can break the python-pip package.
python -m pip install -r "$ROOT_DIR/requirements.txt"

ARCH="$(uname -m)"
case "$ARCH" in
    aarch64) NGROK_ARCH="arm64" ;;
    armv7l|armv8l|arm) NGROK_ARCH="arm" ;;
    x86_64) NGROK_ARCH="amd64" ;;
    i686|i386) NGROK_ARCH="386" ;;
    *) printf 'Unsupported Android architecture: %s\n' "$ARCH" >&2; exit 1 ;;
esac

if [[ ! -x "$NGROK" ]] || ! "$NGROK" version >/dev/null 2>&1; then
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    URL="${NGROK_DOWNLOAD_URL:-https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-${NGROK_ARCH}.zip}"
    printf 'Downloading ngrok for %s...\n' "$ARCH"
    curl -fL --retry 10 --retry-all-errors --retry-delay 5 \
        --connect-timeout 30 --max-time 3600 -C - "$URL" \
        -o "$TMP_DIR/ngrok.zip"
    unzip -o "$TMP_DIR/ngrok.zip" -d "$TMP_DIR"
    install -m 755 "$TMP_DIR/ngrok" "$NGROK"
fi

[[ -x "$NGROK" ]] || { printf 'ngrok installation failed: %s\n' "$NGROK" >&2; exit 1; }

printf '\nngrok Authtoken setup\n'
printf 'Create or copy your token from https://dashboard.ngrok.com/get-started/your-authtoken\n'
read -r -s -p 'Enter your ngrok Authtoken: ' TOKEN
printf '\n'
[[ -n "$TOKEN" ]] || { printf 'Token cannot be empty.\n' >&2; exit 1; }
"$NGROK" config add-authtoken "$TOKEN"
unset TOKEN

chmod +x "$ROOT_DIR/tmcp.sh"
# Remove legacy wrappers from earlier development installs. They can appear
# before $PREFIX/bin in PATH and point to a stale ~/.termux/bin/ngrok path.
for LEGACY_BIN in "$HOME/.termux/bin/tmcp" "$HOME/bin/tmcp"; do
    if [[ -f "$LEGACY_BIN" ]] && grep -q 'termux-mcp\|tmcp.sh' "$LEGACY_BIN" 2>/dev/null; then
        rm -f "$LEGACY_BIN"
    fi
done
INSTALL_BIN="$PREFIX/bin/tmcp"
cat > "$INSTALL_BIN" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -e
PROJECT_DIR="$ROOT_DIR"
if [[ ! -f "\$PROJECT_DIR/tmcp.sh" && -f "\$HOME/termux-mcp/tmcp.sh" ]]; then
    PROJECT_DIR="\$HOME/termux-mcp"
fi
exec "\$PROJECT_DIR/tmcp.sh" "\$@"
EOF
chmod 755 "$INSTALL_BIN"

"$NGROK" version >/dev/null 2>&1 || { printf 'ngrok was installed but could not be executed.\n' >&2; exit 1; }
printf '\nInstallation complete. Start the bridge with:\n  tmcp\n\n'
printf 'The MCP URL will be printed after ngrok connects.\n'
