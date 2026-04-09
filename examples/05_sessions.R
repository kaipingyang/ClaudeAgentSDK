## 05_sessions.R
## Demonstrates session management: list, resume, continue, fork

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# 1. Run a session and capture its session_id
# ---------------------------------------------------------------------------
cat("=== Create a session ===\n")

result <- claude_run(
  "Remember: the magic number is 42.",
  options = ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions"
  )
)
session_id <- result$result$session_id
cat("Session ID:", session_id, "\n\n")

# ---------------------------------------------------------------------------
# 2. List recent sessions for this project directory
# ---------------------------------------------------------------------------
cat("=== list_sessions() ===\n")

sessions <- list_sessions(directory = getwd(), limit = 5L)
cat("Found", length(sessions), "session(s)\n")
for (s in sessions) {
  cat(" -", s$session_id, "|", s$summary %||% "(no summary)", "\n")
}

# ---------------------------------------------------------------------------
# 3. Resume a specific session (--resume flag)
# ---------------------------------------------------------------------------
cat("\n=== Resume session ===\n")

if (nzchar(session_id)) {
  result2 <- claude_run(
    "What is the magic number I told you earlier?",
    options = ClaudeAgentOptions(
      resume          = session_id,
      max_turns       = 1L,
      permission_mode = "bypassPermissions"
    )
  )
  for (msg in result2$messages) {
    if (inherits(msg, "AssistantMessage")) {
      for (block in msg$content) {
        if (inherits(block, "TextBlock")) cat("Resume reply:", block$text, "\n")
      }
    }
  }
}

# ---------------------------------------------------------------------------
# 4. Continue the most-recent session (--continue flag)
# ---------------------------------------------------------------------------
cat("\n=== Continue most-recent session ===\n")

result3 <- claude_run(
  "Double that magic number.",
  options = ClaudeAgentOptions(
    continue_conversation = TRUE,
    max_turns             = 1L,
    permission_mode       = "bypassPermissions"
  )
)
for (msg in result3$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Continue reply:", block$text, "\n")
    }
  }
}

# ---------------------------------------------------------------------------
# 5. get_session_info() — metadata for a specific session
# ---------------------------------------------------------------------------
cat("\n=== get_session_info() ===\n")

info <- get_session_info(session_id)
if (!is.null(info)) {
  cat("summary:", info$summary %||% "(none)", "\n")
  cat("messages:", info$message_count %||% "?", "\n")
} else {
  cat("(session info not found — session may not be written to disk yet)\n")
}
