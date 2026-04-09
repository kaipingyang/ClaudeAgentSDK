## 07_agents.R
## Mirrors: agents.py + filesystem_agents.py
## Demonstrates: AgentDefinition, custom agents passed via ClaudeAgentOptions

library(ClaudeAgentSDK)

# Resolve SDK root directory (works both via Rscript and interactively)
.this_dir <- local({
  args  <- commandArgs(trailingOnly = FALSE)
  flag  <- args[startsWith(args, "--file=")]
  if (length(flag)) dirname(normalizePath(sub("--file=", "", flag), mustWork = FALSE))
  else getwd()
})
.sdk_root <- normalizePath(file.path(.this_dir, ".."), mustWork = FALSE)

# ---------------------------------------------------------------------------
# 1. Single custom agent — code reviewer  (agents.py)
# ---------------------------------------------------------------------------
cat("=== 1. Code Reviewer Agent ===\n")

result <- claude_run(
  "Use the code-reviewer agent to briefly review the R/types.R file",
  options = ClaudeAgentOptions(
    cwd = .sdk_root,
    agents = list(
      "code-reviewer" = AgentDefinition(
        description = "Reviews code for best practices and potential issues",
        prompt      = paste(
          "You are a code reviewer. Analyze code for bugs, performance issues,",
          "and adherence to best practices. Provide brief constructive feedback."
        ),
        tools = c("Read", "Grep"),
        model = "claude-sonnet-4-6"
      )
    ),
    max_turns = 5L
  )
)
for (msg in result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock") && nzchar(trimws(block$text))) {
        cat("Claude:", block$text, "\n")
      }
    }
  }
}
if (!is.null(result$result$total_cost_usd)) {
  cat("Cost: $", result$result$total_cost_usd, "\n")
}

# ---------------------------------------------------------------------------
# 2. Documentation writer agent  (agents.py)
# ---------------------------------------------------------------------------
cat("\n=== 2. Documentation Writer Agent ===\n")

result2 <- claude_run(
  "Use the doc-writer agent to briefly explain what AgentDefinition is used for",
  options = ClaudeAgentOptions(
    agents = list(
      "doc-writer" = AgentDefinition(
        description = "Writes comprehensive technical documentation",
        prompt      = paste(
          "You are a technical documentation expert. Write clear, concise documentation.",
          "Focus on clarity and give a brief example."
        ),
        tools = c("Read"),
        model = "claude-sonnet-4-6"
      )
    ),
    max_turns = 3L
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
if (!is.null(result2$result$total_cost_usd)) {
  cat("Cost: $", result2$result$total_cost_usd, "\n")
}

# ---------------------------------------------------------------------------
# 3. Multiple agents  (agents.py: multiple_agents_example)
# ---------------------------------------------------------------------------
cat("\n=== 3. Multiple Agents ===\n")

result3 <- claude_run(
  "Use the analyzer agent to list R files in the examples/ directory",
  options = ClaudeAgentOptions(
    cwd = getwd(),
    agents = list(
      "analyzer" = AgentDefinition(
        description = "Analyzes code structure and file organization",
        prompt      = "You are a code analyzer. Examine file structures.",
        tools       = c("Glob", "Grep")
      ),
      "tester" = AgentDefinition(
        description = "Creates and reviews tests",
        prompt      = "You are a testing expert. Review test coverage.",
        tools       = c("Read", "Glob"),
        model       = "claude-sonnet-4-6"
      )
    ),
    setting_sources = c("user", "project"),
    max_turns       = 5L
  )
)
for (msg in result3$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock") && nzchar(trimws(block$text))) {
        cat("Claude:", block$text, "\n")
      }
    }
  }
}
if (!is.null(result3$result$total_cost_usd)) {
  cat("Cost: $", result3$result$total_cost_usd, "\n")
}
