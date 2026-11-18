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
#' @examples
#' err <- tryCatch(
#'   claude_cli_not_found("/bad/path/claude"),
#'   error = function(e) e
#' )
#' inherits(err, "claude_error_cli_not_found")
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
#' @examples
#' err <- tryCatch(
#'   claude_cli_connection_error("Connection refused"),
#'   error = function(e) e
#' )
#' inherits(err, "claude_error_cli_connection")
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
#' @examples
#' err <- tryCatch(
#'   claude_process_error("Process failed", exit_code = 1L),
#'   error = function(e) e
#' )
#' inherits(err, "claude_error_process")
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
#' @examples
#' err <- tryCatch(
#'   claude_json_decode_error("{bad json"),
#'   error = function(e) e
#' )
#' inherits(err, "claude_error_json_decode")
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
#' @examples
#' err <- tryCatch(
#'   claude_message_parse_error("Unknown message type", data = list(type = "x")),
#'   error = function(e) e
#' )
#' inherits(err, "claude_error_message_parse")
#' @export
claude_message_parse_error <- function(message, data = NULL, ...) {
  claude_error(
    message,
    class = "claude_error_message_parse",
    data  = data,
    ...
  )
}


#' Build a ResultError condition from a terminal error ResultMessage
#'
#' Mirrors the Python SDK's `ResultError` (v0.2.140): a process error carrying the
#' structured terminal payload (`subtype`, `errors`, `result`, `api_error_status`,
#' `terminal_reason`, `session_id`). Returned, not signalled; use `stop(cond)`.
#' Unlike Python, the SDK does not raise it automatically on process exit: R
#' clients receive the error `ResultMessage` itself and can convert it.
#' @param result A `ResultMessage` with `is_error = TRUE`.
#' @param exit_code,stderr Optional process exit details.
#' @return A condition of class `claude_result_error` (also `claude_process_error`).
#' @export
result_error <- function(result, exit_code = NULL, stderr = NULL) {
  # Normalise like Python: a bare string becomes a list; trim; drop blank and
  # non-string entries.
  raw <- result$errors %||% list()
  if (is.character(raw) && length(raw) == 1L) raw <- list(raw)
  errors <- Filter(function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x)), raw)
  errors <- lapply(errors, trimws)
  detail <- if (length(errors)) paste(unlist(errors), collapse = "; ")
            else if (is.character(result$result)) trimws(result$result) else ""
  message <- paste0("Claude Code returned an error result (", result$subtype %||% "error", ")",
                    if (nzchar(detail)) paste0(": ", detail) else "")
  structure(
    class = c("claude_result_error", "claude_process_error", "claude_error_process",
              "claude_error", "error", "condition"),
    list(message = message, call = NULL, subtype = result$subtype, errors = errors,
         result = result$result, api_error_status = result$api_error_status,
         terminal_reason = result$terminal_reason, session_id = result$session_id,
         exit_code = exit_code, stderr = stderr)
  )
}
