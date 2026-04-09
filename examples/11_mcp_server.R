## 11_mcp_server.R
## Mirrors: mcp_calculator.py
## Demonstrates: R-based in-process MCP server via mcptools + ellmer.
##
## Python uses create_sdk_mcp_server() for in-process tools.
## R uses mcptools::mcp_server() running as a stdio subprocess — functionally
## identical from Claude's perspective, just started differently.
##
## Prerequisites:
##   install.packages(c("mcptools", "ellmer"))

library(ClaudeAgentSDK)

# Resolve this script's directory (works both via Rscript and interactively)
.this_dir <- local({
  args  <- commandArgs(trailingOnly = FALSE)
  flag  <- args[startsWith(args, "--file=")]
  if (length(flag)) dirname(normalizePath(sub("--file=", "", flag), mustWork = FALSE))
  else getwd()
})

# ---------------------------------------------------------------------------
# r_mcp_server() creates the mcp_servers entry that launches:
#   Rscript -e "mcptools::mcp_server(tools = 'mcp_tools_def.R', ...)"
# ---------------------------------------------------------------------------

tools_script <- file.path(.this_dir, "mcp_tools_def.R")

# Verify mcptools is available
if (!requireNamespace("mcptools", quietly = TRUE) ||
    !requireNamespace("ellmer",   quietly = TRUE)) {
  stop("Please install mcptools and ellmer:\n  install.packages(c('mcptools', 'ellmer'))")
}

cat("=== R MCP Calculator (via mcptools) ===\n")
cat("Tools script:", tools_script, "\n\n")

# ---------------------------------------------------------------------------
# 1. Simple addition
# ---------------------------------------------------------------------------
cat("--- Test 1: simple addition ---\n")

result <- claude_run(
  "Use the calculator to compute 1234 + 5678. Show the result.",
  options = ClaudeAgentOptions(
    mcp_servers   = list(calculator = r_mcp_server(tools_script)),
    allowed_tools = "mcp__calculator__fun",   # wildcard: "mcp__calculator__*"
    max_turns     = 3L,
    permission_mode = "bypassPermissions"
  )
)
for (msg in result$messages) {
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
cat("Cost: $", result$result$total_cost_usd, "\n\n")

# ---------------------------------------------------------------------------
# 2. Multi-operation chain
# ---------------------------------------------------------------------------
cat("--- Test 2: multi-operation chain ---\n")

result2 <- claude_run(
  paste(
    "Using the calculator tools, compute step by step:",
    "(100 + 50) * 3 - 75",
    "Show each intermediate result."
  ),
  options = ClaudeAgentOptions(
    mcp_servers     = list(calculator = r_mcp_server(tools_script)),
    allowed_tools   = c("mcp__calculator__fun"),
    max_turns       = 8L,
    permission_mode = "bypassPermissions"
  )
)
for (msg in result2$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock") && nzchar(trimws(block$text))) {
        cat("Claude:", block$text, "\n")
      }
    }
  }
}
cat("Cost: $", result2$result$total_cost_usd, "\n\n")
