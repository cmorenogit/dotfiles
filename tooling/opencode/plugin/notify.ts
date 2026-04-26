import type { Plugin } from "@opencode-ai/plugin"

export const NotifyPlugin: Plugin = async ({ $ }) => {
  return {
    // Hook para detectar preguntas interactivas (mcp_question)
    "tool.execute.before": async (input, output) => {
      if (input.tool === "question") {
        await $`afplay /System/Library/Sounds/Ping.aiff`
      }
    },

    event: async ({ event }) => {
      // Sonido cuando OpenCode solicita permiso
      if (event.type === "permission.updated") {
        await $`afplay /System/Library/Sounds/Ping.aiff`
      }

      // Sonido cuando la sesión termine (idle)
      if (event.type === "session.idle") {
        await $`afplay /System/Library/Sounds/Glass.aiff`
      }

      // Sonido si hay error
      if (event.type === "session.error") {
        await $`afplay /System/Library/Sounds/Basso.aiff`
      }
    },
  }
}
