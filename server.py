import os
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path

from mcp.server.mcpserver import MCPServer

server = MCPServer("Termux")

BASH = "/data/data/com.termux/files/usr/bin/bash"

# Live command log. tmcp.sh shows it in the server terminal; you can also run:
#   tail -f "$TMPDIR/termux-mcp/commands.log"
CMD_LOG = Path(
    os.environ.get("TMCP_CMD_LOG")
    or Path(os.environ.get("TMPDIR", "/tmp")) / "termux-mcp" / "commands.log"
)
MAX_LOG_LINES = int(os.environ.get("TMCP_LOG_MAX_LINES", "200"))
MAX_LINE_CHARS = 300

_log_lock = threading.Lock()


def log(message: str) -> None:
    """Append one timestamped line to the command log. Never raises."""
    stamp = datetime.now().strftime("%H:%M:%S")
    try:
        CMD_LOG.parent.mkdir(parents=True, exist_ok=True)
        with _log_lock, CMD_LOG.open("a", encoding="utf-8") as f:
            f.write(f"[{stamp}] {message}\n")
    except OSError:
        pass  # logging must never break a command


def run_logged(command: str) -> str:
    """Run a command in bash, logging it and streaming its output live."""
    started = time.monotonic()
    first, *rest = command.splitlines() or [""]
    log(f">> {first}")
    for extra in rest:
        log(f"   {extra}")

    try:
        proc = subprocess.Popen(
            command,
            shell=True,
            executable=BASH,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            bufsize=1,
        )
        lines = []
        hidden = 0
        for line in proc.stdout:
            lines.append(line)
            if len(lines) <= MAX_LOG_LINES:
                log(f"   | {line.rstrip()[:MAX_LINE_CHARS]}")
            else:
                hidden += 1
        code = proc.wait()
    except Exception as exc:
        log(f"!! error: {exc}")
        return f"Error: {exc}"

    if hidden:
        log(f"   | ... {hidden} more output lines not shown")
    elapsed = time.monotonic() - started
    log(f"{'OK  ' if code == 0 else 'FAIL'} exit={code} ({elapsed:.1f}s)")

    output = "".join(lines)
    if not output:
        output = f"Command finished with exit code {code}"
    return output


@server.tool()
def shell(command: str) -> str:
    """Execute a Bash command in the user's Termux environment.

    This intentionally provides the same command access as the Termux user.
    Only connect trusted MCP clients and keep the public URL private.
    """
    return run_logged(command)


if __name__ == "__main__":
    log("== Termux MCP server started ==")
    server.run(
        transport="streamable-http",
        host="0.0.0.0",
        port=8000
    )
