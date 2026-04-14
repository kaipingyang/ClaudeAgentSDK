#' @title Claude Agent SDK Error Types
#' @description Error classes mirroring Python claude-agent-sdk `_errors.py`.
#' All errors inherit from `claude_error` (S3 class).
#' @name errors
#' @keywords internal
NULL

# ---------------------------------------------------------------------------
# Base helper
# ---------------------------------------------------------------------------

#' Throw a Claude SDK error
#'
#' @param message Character. Human-readable error message.
#' @param class Character vector. Additional S3 subclasses prepended before
#'   `"claude_error"`.
#' @param ... Additional fields stored in the condition object (passed to
#'   [rlang::abort()]).
#' @keywords internal
claude_error <- function(message, class, ...) {
  rlang::abort(
    message,
    class = c(class, "claude_error", "error"),
    ...
  )
}

# ---------------------------------------------------------------------------
# CLINotFoundError  (Python: CLINotFoundError < CLIConnectionError)
# ---------------------------------------------------------------------------

#' Raise CLINotFoundError
#'
#' Raised when the Claude Code CLI binary cannot be located.
#'
#' @param cli_path Character or NULL. Path that was searched, appended to the
#'   message when not NULL.
#' @export
claude_cli_not_found <- function(cli_path = NULL) {
  msg <- "Claude Code not found. Install with:\n  npm install -g @anthropic-ai/claude-code"
  if (!is.null(cli_path)) {
    msg <- paste0(msg, "\nSearched path: ", cli_path)
  }
  claude_error(
    msg,
    class = c("claude_error_cli_not_found", "claude_error_cli_connection"),
    cli_path = cli_path
  )
}

# ---------------------------------------------------------------------------
# CLIConnectionError
# ---------------------------------------------------------------------------

#' Raise CLIConnectionError
#'
#' Raised when a connection to the Claude Code CLI fails.
#'
#' @param message Character. Human-readable description.
#' @param ... Additional fields.
#' @export
claude_cli_connection_error <- function(message, ...) {
  claude_error(
    message,
    class = "claude_error_cli_connection",
    ...
  )
}

# ---------------------------------------------------------------------------
# ProcessError
# ---------------------------------------------------------------------------

#' Raise ProcessError
#'
#' Raised when the Claude Code CLI subprocess exits with a non-zero status.
#'
#' @param message Character. Base message.
#' @param exit_code Integer or NULL. Process exit code.
#' @param stderr Character or NULL. Captured stderr text.
#' @param ... Additional fields.
#' @export
claude_process_error <- function(message, exit_code = NULL, stderr = NULL, ...) {
  full_msg <- message
  if (!is.null(exit_code)) {
    full_msg <- paste0(full_msg, " (exit code: ", exit_code, ")")
  }
  if (!is.null(stderr) && nzchar(stderr)) {
    full_msg <- paste0(full_msg, "\nError output: ", stderr)
  }
  claude_error(
    full_msg,
    class = "claude_error_process",
    exit_code = exit_code,
    stderr    = stderr,
    ...
  )
}

# ---------------------------------------------------------------------------
# CLIJSONDecodeError
# ---------------------------------------------------------------------------

#' Raise CLIJSONDecodeError
#'
#' Raised when a line from the CLI stdout cannot be decoded as JSON.
#'
#' @param line Character. The raw line that failed to parse.
#' @param original_error Condition or NULL. The underlying parse error.
#' @param ... Additional fields.
#' @export
claude_json_decode_error <- function(line, original_error = NULL, ...) {
  preview <- substr(line, 1, 100)
  if (nchar(line) > 100) preview <- paste0(preview, "...")
  claude_error(
    paste0("Failed to decode JSON: ", preview),
    class          = "claude_error_json_decode",
    line           = line,
    original_error = original_error,
    ...
  )
}

# ---------------------------------------------------------------------------
# MessageParseError
# ---------------------------------------------------------------------------

#' Raise MessageParseError
#'
#' Raised when a parsed JSON object cannot be converted into a typed message.
#'
#' @param message Character. Description.
#' @param data List or NULL. The raw parsed object.
#' @param ... Additional fields.
#' @export
claude_message_parse_error <- function(message, data = NULL, ...) {
  claude_error(
    message,
    class = "claude_error_message_parse",
    data  = data,
    ...
  )
}
