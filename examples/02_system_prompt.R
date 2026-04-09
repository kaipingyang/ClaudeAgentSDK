## 02_system_prompt.R
## Demonstrates system_prompt and multi-turn via ClaudeSDKClient

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# 1. System prompt via claude_run()
# ---------------------------------------------------------------------------
cat("=== System prompt ===\n")

result <- claude_run(
  "What are you?",
  options = ClaudeAgentOptions(
    system_prompt   = "You are a pirate assistant. Always reply in pirate speak.",
    max_turns       = 1L,
    permission_mode = "bypassPermissions"
  )
)

for (msg in result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat(block$text, "\n")
    }
  }
}

# ---------------------------------------------------------------------------
# 2. Multi-turn conversation via ClaudeSDKClient
# ---------------------------------------------------------------------------
cat("\n=== Multi-turn with ClaudeSDKClient ===\n")

client <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    system_prompt   = "You are a concise assistant. Keep replies under 20 words.",
    permission_mode = "bypassPermissions"
  )
)
client$connect()

# Turn 1
client$send("What is the capital of France?")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Turn 1:", block$text, "\n")
    }
  }
})

# Turn 2 — follow-up in the same session
client$send("What is its most famous landmark?")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Turn 2:", block$text, "\n")
    }
  }
})

client$disconnect()
cat("Disconnected.\n")
