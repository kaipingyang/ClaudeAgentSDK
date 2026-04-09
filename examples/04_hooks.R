## 04_hooks.R
## Mirrors: hooks.py
## Demonstrates: PreToolUse, PostToolUse, UserPromptSubmit hooks,
##               permissionDecision allow/deny, continue_=FALSE + stopReason

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# Hook callback helpers
# ---------------------------------------------------------------------------

# Blocks commands matching a pattern (PreToolUse)
check_bash_command <- function(input_data, tool_use_id, context) {
  if (!identical(input_data$tool_name, "Bash")) return(list())
  command <- input_data$tool_input$command %||% ""
  for (pat in c("foo.sh")) {
    if (grepl(pat, command, fixed = TRUE)) {
      message("[hook] Blocked command: ", command)
      return(list(
        hookSpecificOutput = list(
          hookEventName            = "PreToolUse",
          permissionDecision       = "deny",
          permissionDecisionReason = paste("Command contains invalid pattern:", pat)
        )
      ))
    }
  }
  list()
}

# Adds context at session start (UserPromptSubmit)
add_custom_instructions <- function(input_data, tool_use_id, context) {
  list(
    hookSpecificOutput = list(
      hookEventName     = "UserPromptSubmit",
      additionalContext = "My favorite color is hot pink"
    )
  )
}

# Reviews tool output and flags errors (PostToolUse)
review_tool_output <- function(input_data, tool_use_id, context) {
  tool_response <- input_data$tool_response %||% ""
  if (grepl("error", tool_response, ignore.case = TRUE)) {
    return(list(
      systemMessage = "Warning: The command produced an error",
      hookSpecificOutput = list(
        hookEventName     = "PostToolUse",
        additionalContext = "The command encountered an error. Consider a different approach."
      )
    ))
  }
  list()
}

# Blocks writes to 'important' files, allows everything else (PreToolUse)
strict_approval_hook <- function(input_data, tool_use_id, context) {
  tool_name  <- input_data$tool_name  %||% ""
  tool_input <- input_data$tool_input %||% list()
  if (identical(tool_name, "Write")) {
    fp <- tool_input$file_path %||% ""
    if (grepl("important", fp, ignore.case = TRUE)) {
      message("[hook] Blocked Write to: ", fp)
      return(list(
        reason        = "Writes to files containing 'important' are not allowed",
        systemMessage = "Write operation blocked by security policy",
        hookSpecificOutput = list(
          hookEventName            = "PreToolUse",
          permissionDecision       = "deny",
          permissionDecisionReason = "Security policy blocks writes to important files"
        )
      ))
    }
  }
  list(
    hookSpecificOutput = list(
      hookEventName            = "PreToolUse",
      permissionDecision       = "allow",
      permissionDecisionReason = "Tool passed security checks"
    )
  )
}

# Stops execution when output contains 'critical' (PostToolUse)
stop_on_error_hook <- function(input_data, tool_use_id, context) {
  tool_response <- input_data$tool_response %||% ""
  if (grepl("critical", tool_response, ignore.case = TRUE)) {
    message("[hook] Critical error detected - stopping execution")
    return(list(
      continue_     = FALSE,
      stopReason    = "Critical error detected in tool output - execution halted",
      systemMessage = "Execution stopped due to critical error"
    ))
  }
  list(continue_ = TRUE)
}

# ---------------------------------------------------------------------------
# 1. PreToolUse — block certain bash commands  (hooks.py: example_pretooluse)
# ---------------------------------------------------------------------------
cat("=== 1. PreToolUse: block 'foo.sh' pattern ===\n")

client <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    allowed_tools = "Bash",
    hooks = list(
      PreToolUse = list(HookMatcher(matcher = "Bash", hooks = list(check_bash_command)))
    )
  )
)
client$connect()

cat("Test 1: command our hook should block...\n")
client$send("Run the bash command: ./foo.sh --help")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
})

cat("\nTest 2: safe command our hook should allow...\n")
client$send("Run the bash command: echo 'Hello from hooks example!'")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
})
client$disconnect()

# ---------------------------------------------------------------------------
# 2. UserPromptSubmit — add context at prompt submission
# ---------------------------------------------------------------------------
cat("\n=== 2. UserPromptSubmit: inject context ===\n")

client2 <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    hooks = list(
      UserPromptSubmit = list(
        HookMatcher(matcher = NULL, hooks = list(add_custom_instructions))
      )
    )
  )
)
client2$connect()
client2$send("What's my favorite color?")
coro::loop(for (msg in client2$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
})
client2$disconnect()

# ---------------------------------------------------------------------------
# 3. PostToolUse — review output, flag errors
# ---------------------------------------------------------------------------
cat("\n=== 3. PostToolUse: flag errors ===\n")

client3 <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    allowed_tools = "Bash",
    hooks = list(
      PostToolUse = list(HookMatcher(matcher = "Bash", hooks = list(review_tool_output)))
    )
  )
)
client3$connect()
client3$send("Run: ls /nonexistent_directory_xyz")
coro::loop(for (msg in client3$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
})
client3$disconnect()

# ---------------------------------------------------------------------------
# 4. PreToolUse — permissionDecision allow/deny with reason
# ---------------------------------------------------------------------------
cat("\n=== 4. PreToolUse: permissionDecision allow/deny ===\n")

client4 <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    allowed_tools = c("Write", "Bash"),
    hooks = list(
      PreToolUse = list(HookMatcher(matcher = "Write", hooks = list(strict_approval_hook)))
    )
  )
)
client4$connect()

cat("Test — write to important_config.txt (should be blocked):\n")
client4$send("Write the text 'test data' to a file called important_config.txt")
coro::loop(for (msg in client4$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
})

cat("\nTest — write to regular_file.txt (should succeed):\n")
client4$send("Write the text 'test data' to a file called regular_file.txt")
coro::loop(for (msg in client4$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
})
client4$disconnect()

# ---------------------------------------------------------------------------
# 5. PostToolUse — continue_=FALSE to halt execution
# ---------------------------------------------------------------------------
cat("\n=== 5. PostToolUse: continue_=FALSE on critical error ===\n")

client5 <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    allowed_tools   = "Bash",
    permission_mode = "bypassPermissions",
    hooks = list(
      PostToolUse = list(HookMatcher(matcher = "Bash", hooks = list(stop_on_error_hook)))
    )
  )
)
client5$connect()
client5$send("Run this bash command: echo 'CRITICAL ERROR: system failure'")
coro::loop(for (msg in client5$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
  if (inherits(msg, "ResultMessage")) {
    cat("[done] subtype:", msg$subtype, "\n")
  }
})
client5$disconnect()
