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
#   Rscript examples/23_resume.R
#
# =========================================================================

devtools::load_all(quiet = TRUE)

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

# ---------------------------------------------------------------------------
# Part 3: list_sessions() — discover sessions from disk
# ---------------------------------------------------------------------------
cat("\n=== list_sessions(): current project ===\n\n")

proj_sessions <- list_sessions(directory = getwd(), limit = 10L)
cat("Sessions found in this project:", length(proj_sessions), "\n")
for (s in proj_sessions) {
  cat(sprintf("  %s  |  %s\n",
              s$session_id,
              s$summary %||% "(no summary)"))
}

cat("\n=== list_sessions(): all projects (limit 5) ===\n\n")

all_sessions <- list_sessions(limit = 5L)
cat("Sessions (capped at 5):", length(all_sessions), "\n")
for (s in all_sessions) {
  cat(sprintf("  [%s]  %s  |  first_prompt: %s\n",
              basename(s$cwd %||% "?"),
              s$session_id,
              substr(s$first_prompt %||% "(none)", 1, 60)))
}

# ---------------------------------------------------------------------------
# Part 4: get_session_info() + get_session_messages() — read history
# ---------------------------------------------------------------------------
target_sid <- client3$options$resume   # session from Pattern B

cat("\n=== get_session_info() ===\n\n")

info <- get_session_info(target_sid)
if (!is.null(info)) {
  cat("session_id:   ", info$session_id, "\n")
  cat("summary:      ", info$summary %||% "(none)", "\n")
  cat("first_prompt: ", info$first_prompt %||% "(none)", "\n")
  cat("last_modified:", format(info$last_modified), "\n")
  cat("tag:          ", info$tag %||% "(none)", "\n")
} else {
  cat("(not found — session file may not be flushed to disk yet)\n")
}

cat("\n=== get_session_messages() ===\n\n")

msgs <- get_session_messages(target_sid)
cat("Total messages in session:", length(msgs), "\n\n")
for (m in msgs) {
  if (m$type == "user") {
    raw  <- m$message
    text <- if (is.character(raw$content)) raw$content else "(complex content)"
    cat("User:     ", text, "\n")
  } else {
    raw <- m$message
    if (is.list(raw$content)) {
      for (blk in raw$content)
        if (identical(blk[["type"]], "text")) cat("Assistant:", blk[["text"]], "\n")
    } else if (is.character(raw$content)) {
      cat("Assistant:", raw$content, "\n")
    }
  }
}

# ---------------------------------------------------------------------------
# Part 5: Session mutations — rename, tag, fork, delete
# ---------------------------------------------------------------------------
cat("\n=== rename_session() ===\n\n")

rename_session(target_sid, title = "Pattern B demo session")
info2 <- get_session_info(target_sid)
cat("custom_title after rename:", info2$custom_title %||% "(none)", "\n")

cat("\n=== tag_session() ===\n\n")

tag_session(target_sid, tag = "example-run")
info3 <- get_session_info(target_sid)
cat("tag after tag_session():", info3$tag %||% "(none)", "\n")

cat("\n=== fork_session() ===\n\n")

forked_id <- fork_session(target_sid, title = "fork of Pattern B")
cat("Forked session_id:", forked_id, "\n")
forked_info <- get_session_info(forked_id)
cat("Fork custom_title:", forked_info$custom_title %||% "(none)", "\n")

cat("\n=== delete_session() — remove the fork ===\n\n")

delete_session(forked_id)
gone <- get_session_info(forked_id)
cat("Fork still exists after delete:", !is.null(gone), "\n")
