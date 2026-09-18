#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="$SCRIPT_DIR/server.py"
NGROK_BIN="${NGROK_BIN:-$SCRIPT_DIR/ngrok}"
LOG_DIR="${TMPDIR:-/tmp}/termux-mcp"
SERVER_LOG="$LOG_DIR/server.log"
NGROK_LOG="$LOG_DIR/ngrok.log"
SERVER_PID=""
NGROK_PID=""

cleanup() {
    trap - INT TERM EXIT
    printf '\nStopping Termux MCP...\n'
    [[ -n "$NGROK_PID" ]] && kill "$NGROK_PID" 2>/dev/null || true
    [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null || true
    wait "$NGROK_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    printf 'Termux MCP stopped.\n'
}

fail() {
    printf 'Error: %s\n' "$1" >&2
    cleanup
    exit 1
}

command -v python >/dev/null 2>&1 || fail "Python is not installed. Run: pkg install python"
if [[ ! -f "$NGROK_BIN" ]]; then
    fail "ngrok was not found at $NGROK_BIN. Run: cd \"$SCRIPT_DIR\" && ./install.sh"
fi
if [[ ! -x "$NGROK_BIN" ]]; then
    chmod +x "$NGROK_BIN" 2>/dev/null || fail "ngrok exists but cannot be made executable: $NGROK_BIN"
fi
mkdir -p "$LOG_DIR"

printf '%s\n' '========================================'
printf '%s\n' '          Termux MCP starting'
printf '%s\n' '========================================'

python "$SERVER" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
sleep 2
kill -0 "$SERVER_PID" 2>/dev/null || fail "MCP server failed to start. See $SERVER_LOG"

NGROK_ARGS=(http 8000 --log=stdout)
[[ -n "${NGROK_DOMAIN:-}" ]] && NGROK_ARGS+=(--domain "$NGROK_DOMAIN")
termux-chroot "$NGROK_BIN" "${NGROK_ARGS[@]}" >"$NGROK_LOG" 2>&1 &
NGROK_PID=$!
sleep 4
kill -0 "$NGROK_PID" 2>/dev/null || fail "ngrok failed to start. See $NGROK_LOG"

MCP_URL=""
for _ in {1..10}; do
    # ngrok logs also contain update URLs. Match only public tunnel domains.
    MCP_URL="$(grep -oE 'https://[A-Za-z0-9.-]+\.ngrok(-free)?\.(app|dev|io)' "$NGROK_LOG" | head -n 1 || true)"
    [[ -n "$MCP_URL" ]] && break
    sleep 1
done

printf '\n%s\n' '========================================'
printf '%s\n' '             TMCP READY'
printf '%s\n' '========================================'
if [[ -n "$MCP_URL" ]]; then
    printf 'MCP URL:\n%s/mcp\n' "${MCP_URL%/}"
else
    printf 'MCP URL: check the ngrok log at %s\n' "$NGROK_LOG"
fi
printf '\nKeep this URL private. It provides full access to this Termux user.\n'
printf 'Press Ctrl+C to stop the server and tunnel.\n\n'

trap cleanup INT TERM EXIT
wait "$NGROK_PID"
