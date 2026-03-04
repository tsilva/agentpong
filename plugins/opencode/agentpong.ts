import { exec } from "child_process"
import { join } from "path"

export const agentpong = async ({ directory }: { directory: string }) => {
  const notifyScript = join(process.env.HOME || "~", ".opencode", "notify.sh")

  const sendNotification = (message: string) => {
    const env = { ...process.env, OPENCODE_PROJECT_DIR: directory, OPENCODE: "1" }
    exec(`"${notifyScript}" '${message}'`, { env }, () => {})
  }

  return {
    event: async ({ event }: { event: { type: string } }) => {
      if (event.type === "session.idle") {
        sendNotification("Ready for input")
      }
    },
    "permission.ask": async () => {
      sendNotification("Permission required")
    },
  }
}
