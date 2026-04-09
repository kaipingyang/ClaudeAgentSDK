## 08_partial_messages_budget.R
## Mirrors: include_partial_messages.py + max_budget_usd.py
## Demonstrates: include_partial_messages (StreamEvent), max_budget_usd cost control

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# 1. Partial message streaming — see tokens arrive in real time
#    (include_partial_messages.py)
# ---------------------------------------------------------------------------
cat("=== 1. include_partial_messages ===\n")
cat("StreamEvent objects arrive as text is generated.\n\n")

client <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    include_partial_messages = TRUE,
    max_turns                = 1L
  )
)
client$connect()
client$send("Think of three jokes, then tell one")

stream_event_count <- 0L
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "StreamEvent")) {
    stream_event_count <- stream_event_count + 1L
    # Print a dot for each partial event (avoid flooding the console)
    if (stream_event_count %% 5L == 1L) cat(".")
  } else if (inherits(msg, "AssistantMessage")) {
    cat("\n")
    for (block in msg$content) {
      if (inherits(block, "TextBlock") && nzchar(trimws(block$text))) {
        cat("Claude:", block$text, "\n")
      }
    }
  } else if (inherits(msg, "ResultMessage")) {
    cat("[done] stream_events =", stream_event_count,
        "| cost = $", msg$total_cost_usd, "\n")
  }
})
client$disconnect()

# ---------------------------------------------------------------------------
# 2. max_budget_usd — cost control  (max_budget_usd.py)
# ---------------------------------------------------------------------------
cat("\n=== 2. Without budget limit ===\n")

result <- claude_run("What is 2 + 2?")
for (msg in result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
}
cat("Cost: $", result$result$total_cost_usd,
    "| status:", result$result$subtype, "\n")

# ---------------------------------------------------------------------------
cat("\n=== 3. Reasonable budget ($0.10) ===\n")

result2 <- claude_run(
  "What is 2 + 2?",
  options = ClaudeAgentOptions(max_budget_usd = 0.10)
)
for (msg in result2$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
}
cat("Cost: $", result2$result$total_cost_usd,
    "| status:", result2$result$subtype, "\n")

# ---------------------------------------------------------------------------
cat("\n=== 4. Very tight budget ($0.0001) — will likely be exceeded ===\n")

result3 <- claude_run(
  "Read the R/types.R file and summarize it",
  options = ClaudeAgentOptions(max_budget_usd = 0.0001)
)
for (msg in result3$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
}
cat("Cost: $", result3$result$total_cost_usd,
    "| status:", result3$result$subtype, "\n")
if (identical(result3$result$subtype, "error_max_budget_usd")) {
  cat("Budget limit exceeded!\n")
  cat("Note: cost may exceed budget by up to one API call's worth.\n")
}
