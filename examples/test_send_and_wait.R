#!/usr/bin/env Rscript
# Quick integration test for send_and_wait(), get_mcp_status(), get_context_usage()
# Run: ! Rscript examples/test_send_and_wait.R

devtools::load_all(quiet = TRUE)

cat("Connecting to Claude...\n")
client <- ClaudeSDKClient$new(ClaudeAgentOptions())
client$connect()
cat("Connected.\n\n")

# --- get_context_usage ---
cat("Testing get_context_usage()...\n")
cu <- client$get_context_usage()
if (is.null(cu)) {
  cat("  FAIL: returned NULL (timeout or no response)\n")
} else {
  cat("  PASS: got response\n")
  cat("  Content:", paste(names(cu), collapse = ", "), "\n")
  print(cu)
}

cat("\n")

# --- get_mcp_status ---
cat("Testing get_mcp_status()...\n")
ms <- client$get_mcp_status()
if (is.null(ms)) {
  cat("  FAIL: returned NULL (timeout or no response)\n")
} else {
  cat("  PASS: got response\n")
  cat("  Content:", paste(names(ms), collapse = ", "), "\n")
  print(ms)
}

client$disconnect()
cat("\nDone.\n")
