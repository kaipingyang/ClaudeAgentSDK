## 06_advanced.R
## Demonstrates thinking, structured output (JSON schema), runtime control

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# 1. Extended thinking (adaptive)
# ---------------------------------------------------------------------------
cat("=== Extended thinking ===\n")

result <- claude_run(
  "What is 17 * 23? Show your reasoning.",
  options = ClaudeAgentOptions(
    thinking        = list(type = "adaptive"),
    max_turns       = 1L,
    permission_mode = "bypassPermissions"
  )
)

for (msg in result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "ThinkingBlock")) {
        cat("[Thinking]", substr(block$thinking, 1, 120), "...\n")
      }
      if (inherits(block, "TextBlock")) {
        cat("[Reply]", block$text, "\n")
      }
    }
  }
}

# ---------------------------------------------------------------------------
# 2. Structured JSON output via json_schema
# ---------------------------------------------------------------------------
cat("\n=== Structured JSON output ===\n")

result2 <- claude_run(
  "Give me a recipe for scrambled eggs.",
  options = ClaudeAgentOptions(
    output_format = list(
      type   = "json_schema",
      schema = list(
        type       = "object",
        properties = list(
          name        = list(type = "string"),
          ingredients = list(type = "array", items = list(type = "string")),
          steps       = list(type = "array", items = list(type = "string")),
          time_minutes = list(type = "integer")
        ),
        required = c("name", "ingredients", "steps")
      )
    ),
    max_turns       = 1L,
    permission_mode = "bypassPermissions"
  )
)

for (msg in result2$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) {
        cat("Raw JSON:\n", block$text, "\n")
        parsed <- tryCatch(jsonlite::fromJSON(block$text), error = function(e) NULL)
        if (!is.null(parsed)) {
          cat("Parsed name:", parsed$name, "\n")
          cat("Ingredients:", paste(parsed$ingredients, collapse = ", "), "\n")
          cat("Steps:", length(parsed$steps), "steps\n")
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# 3. Runtime control: interrupt + permission mode change
# ---------------------------------------------------------------------------
cat("\n=== Runtime control ===\n")

client <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    max_turns       = 5L,
    permission_mode = "bypassPermissions"
  )
)
client$connect()

# Change permission mode at runtime
client$set_permission_mode("acceptEdits")
cat("Permission mode changed to acceptEdits\n")

# Send a prompt
client$send("Count from 1 to 5, one number per line.")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat(block$text, "\n")
    }
  }
  if (inherits(msg, "ResultMessage")) {
    cat("turns:", msg$num_turns, "| cost: $", msg$total_cost_usd, "\n")
  }
})

client$disconnect()
cat("Done.\n")
