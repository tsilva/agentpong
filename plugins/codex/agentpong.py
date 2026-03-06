#!/usr/bin/env python3
#
# agentpong - Codex CLI Notification Handler
# Receives JSON payload from codex `notify` config and sends notifications.
#
# Usage: agentpong.py '<json-payload>'
#

import json
import os
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: agentpong.py '<json-payload>'", file=sys.stderr)
        return 1

    try:
        notification = json.loads(sys.argv[1])
    except json.JSONDecodeError as e:
        print(f"Failed to parse JSON: {e}", file=sys.stderr)
        return 1

    event_type = notification.get("type", "")

    # Only handle agent-turn-complete for now
    # (codex only supports this event type currently)
    if event_type != "agent-turn-complete":
        return 0

    # Extract relevant fields
    thread_id = notification.get("thread-id", "")
    cwd = notification.get("cwd", os.getcwd())
    last_message = notification.get("last-assistant-message", "Turn complete")
    input_messages = notification.get("input-messages", [])

    # Build notification message
    if input_messages:
        # Show the first user message as context
        message = (
            f"Ready: {input_messages[0][:50]}..."
            if len(input_messages[0]) > 50
            else f"Ready: {input_messages[0]}"
        )
    else:
        message = "Ready for input"

    # Determine tool name and directory
    tool_name = "Codex"
    tool_dir = ".codex"

    # Set up environment for notify.sh
    env = os.environ.copy()
    env["CODEX_PROJECT_DIR"] = cwd
    env["CODEX"] = "1"
    env["CODEX_THREAD_ID"] = thread_id

    # Find notify script
    notify_script = os.path.expanduser(f"~/{tool_dir}/notify.sh")
    if not os.path.exists(notify_script):
        # Fallback to checking if installed elsewhere
        alt_locations = [
            os.path.expanduser("~/.opencode/notify.sh"),
            os.path.expanduser("~/.claude/notify.sh"),
        ]
        for alt in alt_locations:
            if os.path.exists(alt):
                notify_script = alt
                break

    if not os.path.exists(notify_script):
        print(f"notify.sh not found at {notify_script}", file=sys.stderr)
        return 1

    # Send notification
    try:
        subprocess.run(
            [notify_script, message], env=env, check=True, capture_output=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Failed to send notification: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
