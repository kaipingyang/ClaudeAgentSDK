## 01_basic_query.R
## Mirrors: quick_start.py + streaming_mode.py
## Demonstrates: claude_run(), claude_query(), ClaudeSDKClient multi-turn,
##               tool use blocks, interrupt, error handling

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# 1. One-shot blocking call — simplest API  (quick_start.py)
# ---------------------------------------------------------------------------
cat("=== 1. claude_run() — one-shot ===\n")

result <- claude_run(
  "What is 2 + 2? Reply in one sentence.",
  options = ClaudeAgentOptions(max_turns = 1L)
)
for (msg in result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
}
cat("Cost: $", result$result$total_cost_usd,
    " | turns:", result$result$num_turns, "\n\n")

# ---------------------------------------------------------------------------
# 2. Streaming via claude_query()
# ---------------------------------------------------------------------------
cat("=== 2. claude_query() — streaming generator ===\n")

gen <- claude_query(
  "Name three colours of the rainbow (numbered list).",
  options = ClaudeAgentOptions(max_turns = 1L)
)
coro::loop(for (msg in gen) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat(block$text, "\n")
    }
  }
  if (inherits(msg, "ResultMessage")) {
    cat("[done] cost=$", msg$total_cost_usd, "\n")
  }
})

# ---------------------------------------------------------------------------
# 3. Multi-turn conversation — ClaudeSDKClient  (streaming_mode.py)
# ---------------------------------------------------------------------------
cat("\n=== 3. Multi-turn with ClaudeSDKClient ===\n")

client <- ClaudeSDKClient$new(ClaudeAgentOptions())
client$connect()

client$send("What is the capital of France?")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
})

client$send("What is the population of that city?")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
  if (inherits(msg, "ResultMessage")) {
    cat("[done] cost=$", msg$total_cost_usd, "\n")
  }
})

client$disconnect()

# ---------------------------------------------------------------------------
# 4. Inspect tool-use blocks  (streaming_mode.py: example_bash_command)
# ---------------------------------------------------------------------------
cat("\n=== 4. Tool use blocks ===\n")

result <- claude_run(
  "Run: echo 'Hello from R SDK'",
  options = ClaudeAgentOptions(
    allowed_tools   = "Bash",
    permission_mode = "bypassPermissions",
    max_turns       = 3L
  )
)
for (msg in result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock") && nzchar(trimws(block$text))) {
        cat("Claude:", block$text, "\n")
      }
      if (inherits(block, "ToolUseBlock")) {
        cat("Tool call:", block$name, "(id:", block$id, ")\n")
        if (identical(block$name, "Bash")) {
          cat("  command:", block$input$command, "\n")
        }
      }
    }
  }
  if (inherits(msg, "UserMessage")) {
    for (block in msg$content) {
      if (inherits(block, "ToolResultBlock")) {
        content_text <- if (is.character(block$content)) block$content else "(list)"
        cat("Tool result (", block$tool_use_id, "):", substr(content_text, 1, 80), "\n")
      }
    }
  }
}

# ---------------------------------------------------------------------------
# 5. Error handling  (streaming_mode.py: example_error_handling)
# ---------------------------------------------------------------------------
cat("\n=== 5. Error handling ===\n")

tryCatch(
  {
    result <- claude_run("What is 2+2?")
    cat("OK, cost=$", result$result$total_cost_usd, "\n")
  },
  claude_error_cli_not_found = function(e) {
    cat("Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code\n")
  },
  claude_error_process = function(e) {
    cat("Process error (exit code", e$exit_code, "):", conditionMessage(e), "\n")
  },
  claude_error = function(e) {
    cat("SDK error:", conditionMessage(e), "\n")
  }
)
