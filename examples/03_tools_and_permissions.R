## 03_tools_and_permissions.R
## Mirrors: tools_option.py + tool_permission_callback.py
## Demonstrates: tools=, allowed_tools=, disallowed_tools=, can_use_tool callback

library(ClaudeAgentSDK)

# ---------------------------------------------------------------------------
# 1. tools = character vector — limit available built-in tools  (tools_option.py)
# ---------------------------------------------------------------------------
cat("=== 1. tools = c('Read','Glob','Grep') ===\n")

result <- claude_run(
  "What tools do you have available? List them briefly.",
  options = ClaudeAgentOptions(tools = c("Read", "Glob", "Grep"), max_turns = 1L)
)
for (msg in result$messages) {
  if (inherits(msg, "SystemMessage") && identical(msg$subtype, "init")) {
    cat("Tools from init message:", paste(msg$data$tools, collapse = ", "), "\n")
  }
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
}
cat("\n")

# ---------------------------------------------------------------------------
# 2. tools = list() — disable all built-in tools  (tools_option.py)
# ---------------------------------------------------------------------------
cat("=== 2. tools = list() — no built-in tools ===\n")

result2 <- claude_run(
  "What tools do you have available? List them briefly.",
  options = ClaudeAgentOptions(tools = list(), max_turns = 1L)
)
for (msg in result2$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
}
cat("\n")

# ---------------------------------------------------------------------------
# 3. tools = preset  (tools_option.py)
# ---------------------------------------------------------------------------
cat("=== 3. tools = preset 'claude_code' ===\n")

result3 <- claude_run(
  "What tools do you have available? List them briefly.",
  options = ClaudeAgentOptions(
    tools     = list(type = "preset", preset = "claude_code"),
    max_turns = 1L
  )
)
for (msg in result3$messages) {
  if (inherits(msg, "SystemMessage") && identical(msg$subtype, "init")) {
    cat("Total tools:", length(msg$data$tools), "\n")
  }
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) cat("Claude:", block$text, "\n")
    }
  }
}
cat("\n")

# ---------------------------------------------------------------------------
# 4. allowed_tools — auto-approve specific tools
# ---------------------------------------------------------------------------
cat("=== 4. allowed_tools ===\n")

result4 <- claude_run(
  "List files in the current directory using the Bash tool: ls -1",
  options = ClaudeAgentOptions(
    allowed_tools   = "Bash",
    permission_mode = "bypassPermissions",
    max_turns       = 3L,
    cwd             = getwd()
  )
)
for (msg in result4$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock") && nzchar(trimws(block$text))) {
        cat("Claude:", block$text, "\n")
      }
      if (inherits(block, "ToolUseBlock")) {
        cat("Tool call:", block$name, "\n")
      }
    }
  }
}
cat("Cost: $", result4$result$total_cost_usd, "\n\n")

# ---------------------------------------------------------------------------
# 5. disallowed_tools — block specific tools
# ---------------------------------------------------------------------------
cat("=== 5. disallowed_tools ===\n")

result5 <- claude_run(
  "Try to write a file called test_output.txt with content 'hello'",
  options = ClaudeAgentOptions(
    disallowed_tools = "Write",
    permission_mode  = "bypassPermissions",
    max_turns        = 2L
  )
)
for (msg in result5$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock") && nzchar(trimws(block$text))) {
        cat("Claude:", block$text, "\n")
      }
    }
  }
}
cat("\n")

# ---------------------------------------------------------------------------
# 6. can_use_tool callback — programmatic per-call permission control
#    (tool_permission_callback.py)
# ---------------------------------------------------------------------------
cat("=== 6. can_use_tool callback ===\n")

tool_usage_log <- list()

my_permission <- function(tool_name, tool_input, context) {
  tool_usage_log[[length(tool_usage_log) + 1L]] <<- list(
    tool = tool_name, input = tool_input
  )
  cat("  [permission check] tool =", tool_name, "\n")

  # Always allow read-only tools
  if (tool_name %in% c("Read", "Glob", "Grep")) {
    cat("  [ALLOW] read-only tool\n")
    return(PermissionResultAllow())
  }

  # Deny writes to system paths
  if (tool_name %in% c("Write", "Edit", "MultiEdit")) {
    fp <- tool_input$file_path %||% ""
    if (startsWith(fp, "/etc/") || startsWith(fp, "/usr/")) {
      cat("  [DENY] system path:", fp, "\n")
      return(PermissionResultDeny(paste("Cannot write to system directory:", fp)))
    }
    # Redirect writes to ./safe_output/
    if (!startsWith(fp, "/tmp/") && !startsWith(fp, "./")) {
      safe <- file.path(".", "safe_output", basename(fp))
      cat("  [ALLOW, redirect]", fp, "->", safe, "\n")
      modified <- tool_input
      modified$file_path <- safe
      return(PermissionResultAllow(updated_input = modified))
    }
  }

  # Block dangerous Bash commands
  if (tool_name == "Bash") {
    cmd <- tool_input$command %||% ""
    for (pat in c("rm -rf", "sudo", "chmod 777", "dd if=")) {
      if (grepl(pat, cmd, fixed = TRUE)) {
        cat("  [DENY] dangerous pattern:", pat, "\n")
        return(PermissionResultDeny(paste("Dangerous command:", pat)))
      }
    }
    cat("  [ALLOW] bash command:", cmd, "\n")
    return(PermissionResultAllow())
  }

  cat("  [ALLOW] default\n")
  PermissionResultAllow()
}

client <- ClaudeSDKClient$new(
  ClaudeAgentOptions(
    can_use_tool = my_permission,
    max_turns    = 3L
  )
)
client$connect()

client$send("Run: echo 'Hello from R SDK'")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock") && nzchar(trimws(block$text))) {
        cat("Claude:", block$text, "\n")
      }
    }
  }
  if (inherits(msg, "ResultMessage")) {
    cat("[done] cost=$", msg$total_cost_usd, "\n")
  }
})

client$disconnect()

cat("\nTool usage log:\n")
for (i in seq_along(tool_usage_log)) {
  cat(" ", i, ". tool =", tool_usage_log[[i]]$tool, "\n")
}
