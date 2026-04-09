# Example: loading filesystem-based agents via setting_sources
# Mirrors Python filesystem_agents.py
#
# Tests that setting_sources = c("project") correctly loads agents
# defined in .claude/agents/ markdown files on disk.

library(ClaudeAgentSDK)

cat("=== Filesystem Agents Example ===\n")
cat("Testing: setting_sources = c('project') with .claude/agents/\n\n")

# Use the SDK repo directory
sdk_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile), ".."))

opts <- ClaudeAgentOptions(
  setting_sources = c("project"),
  cwd             = sdk_dir,
  max_turns       = 1L,
  permission_mode = "bypassPermissions"
)

client <- ClaudeSDKClient$new(opts)
client$connect()

client$send("Say hello in exactly 3 words")

message_types <- character(0)

coro::loop(for (msg in client$receive_response()) {
  message_types <- c(message_types, class(msg)[[1L]])

  if (inherits(msg, "AssistantMessage")) {
    for (blk in msg$content) {
      if (inherits(blk, "TextBlock")) cat("Assistant:", blk$text, "\n")
    }
  } else if (inherits(msg, "ResultMessage")) {
    cost <- msg$total_cost_usd %||% 0
    cat(sprintf("Result: subtype=%s, cost=$%.4f\n", msg$subtype, cost))
  }
})

client$disconnect()

cat("\n=== Summary ===\n")
cat("Message types received:", paste(message_types, collapse = ", "), "\n")
cat("Total messages:", length(message_types), "\n")

has_assistant <- "AssistantMessage" %in% message_types
has_result    <- "ResultMessage" %in% message_types

if (has_assistant && has_result) {
  cat("SUCCESS: Received full response (assistant, result)\n")
} else {
  cat("FAILURE: Did not receive full response\n")
}
