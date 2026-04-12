#' @title ClaudeSDKClient — Bidirectional Interactive Client
#' @description R6 class for interactive, stateful conversations with Claude
#'   Code.  Mirrors `client.py` from the Python SDK.
#'
#'   For simple one-shot queries use [claude_run()] or [claude_query()].
#' @name client
NULL

#' ClaudeSDKClient R6 Class
#'
#' Provides a stateful, bidirectional connection to the Claude Code CLI.
#' Supports sending multiple prompts, receiving streamed responses, runtime
#' permission-mode changes, interrupts, and MCP server management.
#'
#' @section Lifecycle:
#' ```r
#' client <- ClaudeSDKClient$new(ClaudeAgentOptions(model = "claude-opus-4-6"))
#' client$connect()
#' client$send("Hello, Claude!")
#' coro::loop(for (msg in client$receive_response()) {
#'   if (inherits(msg, "AssistantMessage")) cat(msg$content[[1]]$text)
#' })
#' client$disconnect()
#' ```
#'
#' @export
ClaudeSDKClient <- R6::R6Class(
  "ClaudeSDKClient",

  public = list(

    #' @field options The `ClaudeAgentOptions` used by this client.
    options = NULL,

    #' @description Create a new ClaudeSDKClient.
    #' @param options A `ClaudeAgentOptions` from [ClaudeAgentOptions()].
    #' @param transport Optional `SubprocessCLITransport`. When supplied the
    #'   client uses it directly instead of creating one.
    initialize = function(options   = ClaudeAgentOptions(),
                          transport = NULL) {
      self$options          <- options
      private$custom_transport <- transport
      private$transport     <- NULL
      private$session_id    <- ""
      private$req_counter   <- 0L
      invisible(self)
    },

    # ------------------------------------------------------------------
    # Connection management
    # ------------------------------------------------------------------

    #' @description Connect to Claude Code.
    #' @param prompt Character(1) or NULL. Optional initial prompt to send
    #'   immediately after connecting.
    connect = function(prompt = NULL) {
      if (!is.null(private$transport) && private$is_connected()) {
        return(invisible(self))
      }

      opts <- self$options

      # can_use_tool requires permission_prompt_tool_name = "stdio"
      if (!is.null(opts$can_use_tool)) {
        if (!is.null(opts$permission_prompt_tool_name)) {
          stop("can_use_tool cannot be combined with permission_prompt_tool_name.", call. = FALSE)
        }
        opts_list <- unclass(opts)
        opts_list[["permission_prompt_tool_name"]] <- "stdio"
        opts <- do.call(ClaudeAgentOptions, opts_list)
      }

      if (!is.null(private$custom_transport)) {
        private$transport <- private$custom_transport
      } else {
        private$transport <- SubprocessCLITransport$new(opts)
      }
      private$transport$connect()
      private$init_result <- private$transport$get_init_result()

      # Send initial prompt if provided
      if (!is.null(prompt) && is.character(prompt)) {
        private$transport$send(
          build_user_message_json(prompt, session_id = "default")
        )
      }

      invisible(self)
    },

    #' @description Disconnect from Claude Code and clean up.
    disconnect = function() {
      if (!is.null(private$transport)) {
        tryCatch(private$transport$disconnect(), error = function(e) NULL)
        private$transport <- NULL
      }
      invisible(self)
    },

    # ------------------------------------------------------------------
    # Message sending
    # ------------------------------------------------------------------

    #' @description Send a new prompt to Claude.
    #' @param prompt Character(1) or list. Prompt text or list of content blocks.
    #' @param session_id Character(1). Session identifier (default `"default"`).
    send = function(prompt, session_id = "default") {
      private$assert_connected()
      private$transport$send(
        build_user_message_json(prompt, session_id = session_id)
      )
      invisible(self)
    },

    #' @description Send a new request in streaming mode.
    #'   Alias for [send()] that matches the Python SDK's `client.query()` API.
    #' @param prompt Character(1) or list. Prompt text or list of content blocks.
    #' @param session_id Character(1). Session identifier (default `"default"`).
    query = function(prompt, session_id = "default") {
      self$send(prompt, session_id = session_id)
    },

    # ------------------------------------------------------------------
    # Message receiving
    # ------------------------------------------------------------------

    #' @description Non-blocking single-cycle poll.  Returns a list of
    #'   messages available right now (may be empty).  Designed for
    #'   Shiny `observe()` + `invalidateLater()` polling patterns where
    #'   `later::later()`-based approaches starve input processing.
    #'
    #' @return List of typed message objects (may be empty).
    poll_messages = function() {
      private$assert_connected()
      private$transport$read_available_messages()
    },

    #' @description Return a `coro` generator that yields ALL messages
    #'   (no automatic stop).  Use [receive_response()] for a single
    #'   request/response cycle.
    receive_messages = function() {
      private$assert_connected()
      private$transport$receive_messages()
    },

    #' @description Return a `coro` generator that yields messages until
    #'   and including the next `ResultMessage`, then stops.
    receive_response = function() {
      private$assert_connected()
      gen_inner <- private$transport$receive_messages()
      coro::generator(function() {
        for (msg in gen_inner) {
          coro::yield(msg)
          if (inherits(msg, "ResultMessage")) return(invisible(NULL))
        }
      })()
    },

    #' @description Return a `promises::promise` that resolves to the next
    #'   `ResultMessage`.  Each intermediate message is passed to `on_message`
    #'   as it arrives.  Requires the **promises** package (listed in Suggests).
    #'
    #'   Designed for Shiny `ExtendedTask` integration: the promise keeps the
    #'   Shiny session unblocked while `on_message` streams intermediate
    #'   results (e.g., into a `reactiveVal`) for real-time UI updates.
    #'
    #' @param on_message Function(msg) or NULL.
    #'   Called for every message (AssistantMessage, SystemMessage,
    #'   StreamEvent, PermissionRequestMessage, etc.) except the final
    #'   ResultMessage.  Handle `PermissionRequestMessage` here and call
    #'   `client$approve_tool()` / `client$deny_tool()` to continue.
    #' @param poll_interval Numeric.
    #'   Seconds between non-blocking polls (default 0.01 = 10 ms).
    #' @return A `promises::promise` that resolves to the `ResultMessage`.
    receive_response_async = function(on_message    = NULL,
                                      poll_interval = 0.01) {
      if (!requireNamespace("promises", quietly = TRUE)) {
        stop(
          "The 'promises' package is required for receive_response_async(). ",
          "Install with: install.packages('promises')",
          call. = FALSE
        )
      }
      private$assert_connected()

      transport <- private$transport

      p <- promises::promise(function(resolve, reject) {
        poll_step <- function() {
          if (!transport$is_alive()) {
            reject(simpleError("Claude Code process exited during async receive"))
            return()
          }

          msgs <- tryCatch(
            transport$read_available_messages(),
            error = function(e) {
              reject(e)
              NULL
            }
          )
          if (is.null(msgs)) return()

          for (msg in msgs) {
            if (is.function(on_message)) {
              tryCatch(on_message(msg), error = function(e) {
                warning("on_message callback error: ", conditionMessage(e),
                        call. = FALSE)
              })
            }
            if (inherits(msg, "ResultMessage")) {
              resolve(msg)
              return()
            }
          }

          # Re-arm: schedule next non-blocking poll
          later::later(poll_step, poll_interval)
        }
        poll_step()
      })

      p
    },

    # ------------------------------------------------------------------
    # Tool approval (message-driven API)
    # ------------------------------------------------------------------

    #' @description Approve a pending tool request.
    #'   Call this after receiving a `PermissionRequestMessage` from the
    #'   message stream to allow the tool to execute.
    #' @param request_id Character. The `request_id` from the
    #'   `PermissionRequestMessage`.
    #' @param updated_input List or NULL. Modified tool input (default:
    #'   use original input).
    approve_tool = function(request_id, updated_input = NULL) {
      private$assert_connected()
      pending <- private$transport$get_pending_permission(request_id)
      if (is.null(pending)) {
        stop("No pending permission request with id: ", request_id, call. = FALSE)
      }
      response <- list(
        behavior     = "allow",
        updatedInput = updated_input %||% pending[["input"]]
      )
      private$transport$resolve_pending_permission(request_id, response)
      invisible(self)
    },

    #' @description Deny a pending tool request.
    #' @param request_id Character. The `request_id` from the
    #'   `PermissionRequestMessage`.
    #' @param message Character. Reason for denial (default `"Denied by user"`).
    deny_tool = function(request_id, message = "Denied by user") {
      private$assert_connected()
      pending <- private$transport$get_pending_permission(request_id)
      if (is.null(pending)) {
        stop("No pending permission request with id: ", request_id, call. = FALSE)
      }
      private$transport$resolve_pending_permission(
        request_id,
        list(behavior = "deny", message = message)
      )
      invisible(self)
    },

    # ------------------------------------------------------------------
    # Runtime control
    # ------------------------------------------------------------------

    #' @description Send an interrupt control request.
    interrupt = function() {
      private$assert_connected()
      private$send_control_request(list(subtype = "interrupt"))
      invisible(self)
    },

    #' @description Change the permission mode at runtime.
    #' @param mode Character. One of `"default"`, `"acceptEdits"`,
    #'   `"bypassPermissions"`, `"plan"`, `"dontAsk"`, `"auto"`.
    #' @param destination Character. Where to apply the mode change
    #'   (default `"session"`).
    set_permission_mode = function(mode, destination = "session") {
      private$assert_connected()
      private$send_control_request(list(
        subtype     = "set_permission_mode",
        mode        = mode,
        destination = destination
      ))
      invisible(self)
    },

    #' @description Change the AI model at runtime.
    #' @param model Character or NULL. Model ID, or NULL for default.
    set_model = function(model = NULL) {
      private$assert_connected()
      private$send_control_request(list(subtype = "set_model", model = model))
      invisible(self)
    },

    #' @description Rewind tracked files to their state at a specific
    #'   user message.  Requires `enable_file_checkpointing = TRUE`.
    #' @param user_message_id Character. UUID of the target user message.
    rewind_files = function(user_message_id) {
      private$assert_connected()
      private$send_control_request(list(
        subtype         = "rewind_files",
        user_message_id = user_message_id
      ))
      invisible(self)
    },

    #' @description Stop a running task by ID.
    #' @param task_id Character. Task ID from a `TaskNotificationMessage`.
    stop_task = function(task_id) {
      private$assert_connected()
      private$send_control_request(list(subtype = "stop_task", task_id = task_id))
      invisible(self)
    },

    # ------------------------------------------------------------------
    # Status queries
    # ------------------------------------------------------------------

    #' @description Get MCP server connection status.
    #' @param timeout_ms Integer. Milliseconds to wait for response (default 30 000).
    #' @return Named list with `mcpServers` key, or `NULL` on timeout.
    get_mcp_status = function(timeout_ms = 30000L) {
      private$assert_connected()
      private$transport$send_and_wait(list(subtype = "mcp_status"), timeout_ms)
    },

    #' @description Get context window usage breakdown.
    #' @param timeout_ms Integer. Milliseconds to wait for response (default 30 000).
    #' @return Named list with token counts by category, or `NULL` on timeout.
    get_context_usage = function(timeout_ms = 30000L) {
      private$assert_connected()
      private$transport$send_and_wait(list(subtype = "get_context_usage"), timeout_ms)
    },

    #' @description Get server initialization info.
    #' @return List with server capabilities, or NULL.
    get_server_info = function() {
      private$init_result
    },

    #' @description Reconnect a failed MCP server.
    #' @param server_name Character. Server name.
    reconnect_mcp_server = function(server_name) {
      private$assert_connected()
      private$send_control_request(list(
        subtype    = "mcp_reconnect",
        serverName = server_name
      ))
      invisible(self)
    },

    #' @description Enable or disable an MCP server.
    #' @param server_name Character. Server name.
    #' @param enabled Logical. `TRUE` to enable, `FALSE` to disable.
    toggle_mcp_server = function(server_name, enabled) {
      private$assert_connected()
      private$send_control_request(list(
        subtype    = "mcp_toggle",
        serverName = server_name,
        enabled    = enabled
      ))
      invisible(self)
    }
  ),

  private = list(
    custom_transport = NULL,
    transport        = NULL,
    session_id       = "",
    req_counter      = 0L,
    init_result      = NULL,

    is_connected = function() {
      !is.null(private$transport) && private$transport$is_alive()
    },

    assert_connected = function() {
      if (is.null(private$transport)) {
        claude_cli_connection_error("Not connected. Call $connect() first.")
      }
    },

    # Send a control_request to the CLI via stdin and return immediately.
    # (Non-blocking — used for fire-and-forget control messages.)
    send_control_request = function(request) {
      private$req_counter <- private$req_counter + 1L
      request_id <- paste0("req_", private$req_counter, "_",
                           paste0(as.hexmode(sample.int(256, 4) - 1), collapse = ""))
      json <- jsonlite::toJSON(
        list(type = "control_request", request_id = request_id, request = request),
        auto_unbox = TRUE, null = "null"
      )
      private$transport$send(json)
      invisible(request_id)
    }
  )
)
