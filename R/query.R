#' @title One-shot Query Functions
#' @description High-level API for one-shot interactions with Claude Code.
#'   Mirrors `query.py` from the Python SDK.
#' @name query
#' @keywords internal
NULL

#' Query Claude Code (streaming generator)
#'
#' Creates a `SubprocessCLITransport`, connects to the CLI, sends the
#' prompt, and returns a `coro` generator that yields typed message objects.
#' The generator terminates automatically after the `ResultMessage`.
#'
#' The caller is responsible for disconnecting the transport after the
#' generator is exhausted.  For a simpler synchronous API see [claude_run()].
#'
#' @param prompt Character(1) or list. Prompt text, or a list of content
#'   blocks.
#' @param options A `ClaudeAgentOptions` from [ClaudeAgentOptions()].
#' @param transport Optional `SubprocessCLITransport` R6 object. When
#'   supplied, `connect()` is NOT called automatically — the caller must
#'   have already connected.
#' @return A `coro` generator yielding message objects (see types.R).
#' @export
claude_query <- function(prompt,
                          options   = ClaudeAgentOptions(),
                          transport = NULL) {
  if (is.null(transport)) {
    transport <- SubprocessCLITransport$new(options)
    transport$connect()
  }
  transport$send(build_user_message_json(prompt, session_id = "default"))
  transport$receive_messages()
}

#' Run Claude Code synchronously and collect all messages
#'
#' Convenience wrapper around [claude_query()] that blocks until the
#' `ResultMessage` is received and returns a structured result list.
#' Equivalent to the Python pattern:
#' ```python
#' messages = []
#' async for msg in query(prompt, options): messages.append(msg)
#' ```
#'
#' @param prompt Character(1) or list.
#' @param options A `ClaudeAgentOptions` from [ClaudeAgentOptions()].
#' @param ... Named arguments passed to [ClaudeAgentOptions()], overriding
#'   values in `options`.  E.g. `claude_run("...", max_turns = 1L)`.
#' @return A list of class `ClaudeRunResult` with:
#'   * `$messages` — all messages in order
#'   * `$result` — the `ResultMessage` (or `NULL` if not received)
#' @export
claude_run <- function(prompt, options = ClaudeAgentOptions(), ...) {
  dots <- Filter(Negate(is.null), list(...))
  if (length(dots)) {
    opts_list <- utils::modifyList(unclass(options), dots)
    options   <- do.call(ClaudeAgentOptions, opts_list)
  }

  transport <- SubprocessCLITransport$new(options)
  transport$connect()

  gen      <- claude_query(prompt, options = options, transport = transport)
  messages <- list()

  coro::loop(for (msg in gen) {
    messages <- c(messages, list(msg))
  })

  tryCatch(transport$disconnect(), error = function(e) NULL)

  result_msg <- Filter(function(m) inherits(m, "ResultMessage"), messages)

  structure(
    list(
      messages = messages,
      result   = if (length(result_msg)) result_msg[[1L]] else NULL
    ),
    class = "ClaudeRunResult"
  )
}

#' @export
print.ClaudeRunResult <- function(x, ...) {
  cat("<ClaudeRunResult messages=", length(x$messages), ">\n", sep = "")
  if (!is.null(x$result)) {
    cat("  result: is_error=", x$result$is_error,
        " turns=", x$result$num_turns,
        " cost=$", x$result$total_cost_usd %||% "NA",
        "\n", sep = "")
  }
  invisible(x)
}
