# examples/23_resume.R
# =========================================================================
# Session resume: persist context across multiple client connections
# =========================================================================
#
# Demonstrates the session_id auto-capture and resume workflow:
#
#   Turn 1  →  client$session_id  captures the session_id automatically
#               from ResultMessage after receive_response() completes.
#
#   Pattern A — explicit:
#     ClaudeAgentOptions(resume = client$session_id)
#
#   Pattern B — convenience method:
#     client$resume()  sets options$resume = session_id in place,
#     then client$connect() reconnects with --resume <id>.
#
# Run:
#   Rscript examples/21_resume.R
#
# =========================================================================

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# Helper: collect all text from a receive_response() loop
# ---------------------------------------------------------------------------
collect_text <- function(client) {
  texts <- character(0)
  coro::loop(for (msg in client$receive_response()) {
    if (inherits(msg, "AssistantMessage")) {
      for (blk in msg$content)
        if (inherits(blk, "TextBlock")) texts <- c(texts, blk$text)
    }
  })
  paste(texts, collapse = "")
}

# ---------------------------------------------------------------------------
# Pattern A: pass session_id explicitly to a new options object
# ---------------------------------------------------------------------------
cat("=== Pattern A: explicit session_id ===\n\n")

client <- ClaudeSDKClient$new(ClaudeAgentOptions(
  max_turns       = 1L,
  permission_mode = "bypassPermissions"
))
client$connect()

client$send("Remember the secret code: ZETA-9. Reply only: STORED")
reply1 <- collect_text(client)
cat("Turn 1 reply:", reply1, "\n")

sid <- client$session_id
cat("Captured session_id:", sid, "\n\n")
client$disconnect()

# Resume in a brand-new client using the captured session_id
client2 <- ClaudeSDKClient$new(ClaudeAgentOptions(
  max_turns       = 1L,
  permission_mode = "bypassPermissions",
  resume          = sid          # <-- the key line
))
client2$connect()

client2$send("What was the secret code I told you? Reply with just the code.")
reply2 <- collect_text(client2)
cat("Turn 2 reply:", reply2, "\n")
client2$disconnect()

# ---------------------------------------------------------------------------
# Pattern B: use client$resume() convenience method
# ---------------------------------------------------------------------------
cat("\n=== Pattern B: client$resume() method ===\n\n")

client3 <- ClaudeSDKClient$new(ClaudeAgentOptions(
  max_turns       = 1L,
  permission_mode = "bypassPermissions"
))
client3$connect()

client3$send("Remember the number: 8472. Reply only: STORED")
collect_text(client3)
cat("Turn 1 done. session_id:", client3$session_id, "\n")
client3$disconnect()

# resume() sets options$resume = session_id; next connect() uses --resume
client3$resume()
cat("After resume(), options$resume:", client3$options$resume, "\n\n")

client3$connect()
client3$send("What number did I ask you to remember? Reply with just the number.")
reply3 <- collect_text(client3)
cat("Turn 2 reply:", reply3, "\n")
client3$disconnect()
