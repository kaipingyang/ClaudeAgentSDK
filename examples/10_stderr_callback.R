## 10_stderr_callback.R
## Mirrors: stderr_callback_example.py
## Demonstrates: capturing CLI stderr with a callback + debug-to-stderr flag

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# Collect stderr lines via callback
# ---------------------------------------------------------------------------
stderr_lines <- character(0)

stderr_callback <- function(line) {
  stderr_lines <<- c(stderr_lines, line)
  # Surface ERROR lines immediately
  if (grepl("\\[ERROR\\]", line)) {
    cat("[stderr ERROR]", line, "\n")
  }
}

cat("=== stderr callback + debug output ===\n")
cat("Running query with stderr capture...\n\n")

result <- claude_run(
  "What is 2 + 2?",
  options = ClaudeAgentOptions(
    max_turns   = 1L,
    stderr      = stderr_callback,
    extra_args  = list("debug-to-stderr" = NULL)   # enables verbose debug output
  )
)

for (msg in result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
}

cat("\nCaptured", length(stderr_lines), "stderr line(s)\n")
if (length(stderr_lines) > 0L) {
  cat("First line:", substr(stderr_lines[[1]], 1, 120), "\n")
}
