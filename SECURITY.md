# Security

Termux MCP intentionally exposes a full shell inside the current Termux user account to a trusted MCP client. The public MCP URL must be treated like a temporary remote-control credential.

Do not share the MCP URL with people, agents, or services you do not trust. Stop the bridge with `Ctrl+C` when it is not in use. Never commit or publish an ngrok Authtoken. The token belongs to the user and is stored by the local ngrok configuration.

Termux MCP does not grant Android root access by itself. Its permissions are the permissions available to the current Termux user, including any storage access previously granted to Termux.

If you discover a security issue in the project, please open a private security report where available rather than publishing credentials or a working exploit in a public issue.
