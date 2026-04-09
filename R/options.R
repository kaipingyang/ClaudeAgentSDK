#' Create ClaudeAgentOptions
#'
#' Constructs an options object controlling every aspect of a Claude Code
#' session.  Mirrors the Python SDK's `ClaudeAgentOptions` dataclass
#' field-for-field.
#'
#' @param tools Character vector, named list (`type="preset"`), or NULL.
#'   Base set of tools available to Claude.  Passing `list(type="preset",
#'   preset="claude_code")` maps to `--tools default`.
#' @param allowed_tools Character vector. Additional tools to allow beyond
#'   the base set (`--allowedTools`).
#' @param system_prompt Character, named list (`type="preset"` /
#'   `type="file"`), or NULL.  System prompt text or configuration.
#' @param mcp_servers Named list of MCP server configs, or character path to
#'   an MCP config file.
#' @param permission_mode Character or NULL.  One of `"default"`,
#'   `"acceptEdits"`, `"bypassPermissions"`, `"plan"`, `"dontAsk"`, `"auto"`.
#' @param continue_conversation Logical. Continue the most recent session
#'   (`--continue`).
#' @param resume Character or NULL. Resume a specific session ID
#'   (`--resume`).
#' @param session_id Character or NULL. Explicit session ID to use
#'   (`--session-id`).
#' @param max_turns Integer or NULL. Maximum conversation turns
#'   (`--max-turns`).
#' @param max_budget_usd Numeric or NULL. Budget cap in USD
#'   (`--max-budget-usd`).
#' @param disallowed_tools Character vector. Tools to block
#'   (`--disallowedTools`).
#' @param model Character or NULL. Model ID (`--model`).
#' @param fallback_model Character or NULL. Fallback model ID
#'   (`--fallback-model`).
#' @param betas Character vector. SDK beta feature flags (`--betas`).
#' @param permission_prompt_tool_name Character or NULL. Tool name used for
#'   the permission prompt control protocol (`--permission-prompt-tool`).
#' @param cwd Character or NULL. Working directory for the Claude process.
#' @param cli_path Character or NULL. Explicit path to the `claude` binary.
#' @param settings Character or NULL. Path to a settings JSON file, or a
#'   raw JSON string (`--settings`).
#' @param add_dirs List of character paths. Additional directories to add
#'   (`--add-dir`).
#' @param env Named list of character strings. Extra environment variables
#'   for the subprocess.
#' @param extra_args Named list. Arbitrary extra CLI flags.  Each name
#'   becomes `--<name>`; the value is the flag value (`NULL` for boolean
#'   flags).
#' @param max_buffer_size Integer or NULL. Maximum bytes to buffer from CLI
#'   stdout before raising an error (default 1 MB).
#' @param stderr Function(line) or NULL. Callback receiving each stderr line.
#' @param can_use_tool Function or NULL. Permission callback with signature
#'   `function(tool_name, tool_input, context)` returning a
#'   `PermissionResultAllow` or `PermissionResultDeny`.
#' @param hooks Named list of HookMatcher lists keyed by hook event name.
#' @param user Character or NULL. OS user to run the subprocess as.
#' @param include_partial_messages Logical. Emit partial streaming messages
#'   (`--include-partial-messages`).
#' @param fork_session Logical. Fork resumed session to a new session ID
#'   (`--fork-session`).
#' @param agents Named list of agent definitions.
#' @param setting_sources Character vector or NULL. Setting sources to load
#'   (`--setting-sources`).
#' @param sandbox List or NULL. Sandbox settings dict.
#' @param plugins List of plugin configs (`type="local"`, `path=...`).
#' @param max_thinking_tokens Integer or NULL. **Deprecated**; use `thinking`.
#' @param thinking Named list or NULL. Thinking config
#'   (`list(type="adaptive")`, `list(type="enabled", budget_tokens=N)`,
#'   `list(type="disabled")`).
#' @param effort Character or NULL. Thinking depth: `"low"`, `"medium"`,
#'   `"high"`, `"max"`.
#' @param output_format Named list or NULL. Structured output format, e.g.
#'   `list(type="json_schema", schema=list(...))`.
#' @param enable_file_checkpointing Logical. Track file changes for rewind
#'   support.
#' @param task_budget Named list or NULL. API-side task budget, e.g.
#'   `list(total = 10000L)`.
#'
#' @return Object of class `ClaudeAgentOptions`.
#' @export
ClaudeAgentOptions <- function(
    tools                     = NULL,
    allowed_tools             = character(),
    system_prompt             = NULL,
    mcp_servers               = list(),
    permission_mode           = NULL,
    continue_conversation     = FALSE,
    resume                    = NULL,
    session_id                = NULL,
    max_turns                 = NULL,
    max_budget_usd            = NULL,
    disallowed_tools          = character(),
    model                     = NULL,
    fallback_model            = NULL,
    betas                     = character(),
    permission_prompt_tool_name = NULL,
    cwd                       = NULL,
    cli_path                  = NULL,
    settings                  = NULL,
    add_dirs                  = list(),
    env                       = list(),
    extra_args                = list(),
    max_buffer_size           = NULL,
    stderr                    = NULL,
    can_use_tool              = NULL,
    hooks                     = NULL,
    user                      = NULL,
    include_partial_messages  = FALSE,
    fork_session              = FALSE,
    agents                    = NULL,
    setting_sources           = NULL,
    sandbox                   = NULL,
    plugins                   = list(),
    max_thinking_tokens       = NULL,
    thinking                  = NULL,
    effort                    = NULL,
    output_format             = NULL,
    enable_file_checkpointing = FALSE,
    task_budget               = NULL
) {
  structure(
    list(
      tools                     = tools,
      allowed_tools             = allowed_tools,
      system_prompt             = system_prompt,
      mcp_servers               = mcp_servers,
      permission_mode           = permission_mode,
      continue_conversation     = continue_conversation,
      resume                    = resume,
      session_id                = session_id,
      max_turns                 = max_turns,
      max_budget_usd            = max_budget_usd,
      disallowed_tools          = disallowed_tools,
      model                     = model,
      fallback_model            = fallback_model,
      betas                     = betas,
      permission_prompt_tool_name = permission_prompt_tool_name,
      cwd                       = cwd,
      cli_path                  = cli_path,
      settings                  = settings,
      add_dirs                  = add_dirs,
      env                       = env,
      extra_args                = extra_args,
      max_buffer_size           = max_buffer_size,
      stderr                    = stderr,
      can_use_tool              = can_use_tool,
      hooks                     = hooks,
      user                      = user,
      include_partial_messages  = include_partial_messages,
      fork_session              = fork_session,
      agents                    = agents,
      setting_sources           = setting_sources,
      sandbox                   = sandbox,
      plugins                   = plugins,
      max_thinking_tokens       = max_thinking_tokens,
      thinking                  = thinking,
      effort                    = effort,
      output_format             = output_format,
      enable_file_checkpointing = enable_file_checkpointing,
      task_budget               = task_budget
    ),
    class = "ClaudeAgentOptions"
  )
}

#' @export
print.ClaudeAgentOptions <- function(x, ...) {
  cat("<ClaudeAgentOptions>\n")
  non_default <- Filter(function(v) !is.null(v) && !identical(v, character()) &&
                          !identical(v, list()) && !identical(v, FALSE),
                        unclass(x))
  for (nm in names(non_default)) {
    cat("  ", nm, ": ", deparse(non_default[[nm]], width.cutoff = 60L)[[1]], "\n",
        sep = "")
  }
  invisible(x)
}

