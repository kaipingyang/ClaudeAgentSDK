# Quick start example for ClaudeAgentSDK
# Mirrors Python quick_start.py

library(ClaudeAgentSDK)

# --- Basic example: simple question ---
cat("=== Basic Example ===\n")
result <- claude_run("What is 2 + 2?")
msgs <- Filter(function(m) inherits(m, "AssistantMessage"), result$messages)
for (m in msgs) {
  for (blk in m$content) {
    if (inherits(blk, "TextBlock")) cat("Claude:", blk$text, "\n")
  }
}

# --- With options: custom system prompt ---
cat("\n=== With Options Example ===\n")
result <- claude_run(
  "Explain what R is in one sentence.",
  options = ClaudeAgentOptions(
    system_prompt = "You are a helpful assistant that explains things simply.",
    max_turns     = 1L
  )
)
msgs <- Filter(function(m) inherits(m, "AssistantMessage"), result$messages)
for (m in msgs) {
  for (blk in m$content) {
    if (inherits(blk, "TextBlock")) cat("Claude:", blk$text, "\n")
  }
}

# --- With tools: file operations ---
cat("\n=== With Tools Example ===\n")
result <- claude_run(
  "Create a file called /tmp/hello_sdk.txt with 'Hello, World!' in it",
  options = ClaudeAgentOptions(
    allowed_tools   = c("Read", "Write"),
    system_prompt   = "You are a helpful file assistant.",
    permission_mode = "bypassPermissions"
  )
)
msgs <- Filter(function(m) inherits(m, "AssistantMessage"), result$messages)
for (m in msgs) {
  for (blk in m$content) {
    if (inherits(blk, "TextBlock")) cat("Claude:", blk$text, "\n")
  }
}
if (!is.null(result$result$total_cost_usd) && result$result$total_cost_usd > 0) {
  cat(sprintf("\nCost: $%.4f\n", result$result$total_cost_usd))
}
