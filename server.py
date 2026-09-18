import subprocess

from mcp.server.mcpserver import MCPServer

server = MCPServer("Termux")

@server.tool()
def shell(command: str) -> str:
    """Execute a Bash command in the user's Termux environment.

    This intentionally provides the same command access as the Termux user.
    Only connect trusted MCP clients and keep the public URL private.
    """
    try:
        result = subprocess.run(
            command,
            shell=True,
            executable="/data/data/com.termux/files/usr/bin/bash",
            capture_output=True,
            text=True
        )

        output = result.stdout + result.stderr

        if not output:
            output = f"Command finished with exit code {result.returncode}"

        return output

    except Exception as exc:
        return f"Error: {exc}"

if __name__ == "__main__":
    server.run(
        transport="streamable-http",
        host="0.0.0.0",
        port=8000
    )
