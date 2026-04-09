## 09_setting_sources.R
## Mirrors: setting_sources.py
## Demonstrates: setting_sources controls which settings files Claude loads.
##
## Setting sources:
##   NULL (default) — no settings loaded (isolated environment)
##   "user"         — global ~/.claude/ settings only
##   "project"      — project .claude/ settings only
##   c("user","project") — both

library(ClaudeAgentSDK)

sdk_dir <- normalizePath(
  file.path(local({
    args <- commandArgs(trailingOnly = FALSE)
    flag <- args[startsWith(args, "--file=")]
    if (length(flag)) dirname(normalizePath(sub("--file=", "", flag), mustWork = FALSE))
    else getwd()
  }), ".."),
  mustWork = FALSE
)

extract_slash_commands <- function(messages) {
  for (msg in messages) {
    if (inherits(msg, "SystemMessage") && identical(msg$subtype, "init")) {
      cmds <- msg$data[["slash_commands"]]
      if (!is.null(cmds)) return(cmds)
    }
  }
  character(0)
}

# ---------------------------------------------------------------------------
# 1. Default — no settings loaded  (setting_sources.py: example_default)
# ---------------------------------------------------------------------------
cat("=== 1. Default (setting_sources = NULL) ===\n")
cat("Expected: no custom slash commands\n\n")

client <- ClaudeSDKClient$new(ClaudeAgentOptions(cwd = sdk_dir))
client$connect()
client$send("What is 2 + 2?")

msgs <- list()
coro::loop(for (msg in client$receive_response()) {
  msgs <- c(msgs, list(msg))
})
client$disconnect()

cmds <- extract_slash_commands(msgs)
cat("Slash commands available:", if (length(cmds)) paste(cmds, collapse = ", ") else "(none)", "\n")
if ("commit" %in% cmds) {
  cat("UNEXPECTED: /commit available\n")
} else {
  cat("OK: /commit NOT available (no project settings loaded)\n")
}

# ---------------------------------------------------------------------------
# 2. User settings only  (setting_sources.py: example_user_only)
# ---------------------------------------------------------------------------
cat("\n=== 2. setting_sources = 'user' ===\n")
cat("Expected: global user commands only, NOT project /commit\n\n")

client2 <- ClaudeSDKClient$new(
  ClaudeAgentOptions(cwd = sdk_dir, setting_sources = "user")
)
client2$connect()
client2$send("What is 2 + 2?")

msgs2 <- list()
coro::loop(for (msg in client2$receive_response()) {
  msgs2 <- c(msgs2, list(msg))
})
client2$disconnect()

cmds2 <- extract_slash_commands(msgs2)
cat("Slash commands:", if (length(cmds2)) paste(cmds2, collapse = ", ") else "(none)", "\n")
if ("commit" %in% cmds2) {
  cat("UNEXPECTED: /commit available\n")
} else {
  cat("OK: /commit NOT available (user-only settings)\n")
}

# ---------------------------------------------------------------------------
# 3. User + project settings  (setting_sources.py: example_project_and_user)
# ---------------------------------------------------------------------------
cat("\n=== 3. setting_sources = c('user','project') ===\n")
cat("Expected: project /commit IS available\n\n")

client3 <- ClaudeSDKClient$new(
  ClaudeAgentOptions(cwd = sdk_dir, setting_sources = c("user", "project"))
)
client3$connect()
client3$send("What is 2 + 2?")

msgs3 <- list()
coro::loop(for (msg in client3$receive_response()) {
  msgs3 <- c(msgs3, list(msg))
})
client3$disconnect()

cmds3 <- extract_slash_commands(msgs3)
cat("Slash commands:", if (length(cmds3)) paste(cmds3, collapse = ", ") else "(none)", "\n")
if ("commit" %in% cmds3) {
  cat("OK: /commit available (project settings loaded)\n")
} else {
  cat("Note: /commit not found — project may not have a /commit command defined\n")
}
