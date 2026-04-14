# Shiny Integration: Interactive Tool Approval

This article shows how to let users approve or deny Claude’s tool calls
interactively from a Shiny app — for example, asking “Do you want Claude
to run this Bash command?” before execution.

## Architecture: Message-Driven Approval

The recommended approach uses **message-driven approval** via
`PermissionRequestMessage`. When `permission_prompt_tool_name = "stdio"`
is set and no synchronous `can_use_tool` callback is configured, every
`can_use_tool` control request from the CLI is surfaced as a
`PermissionRequestMessage` in the normal message stream.

The flow:

    CLI sends can_use_tool
            ↓
    SDK yields PermissionRequestMessage (request_id, tool_name, tool_input)
            ↓
    Shiny shows modal dialog (tool name + JSON input)
            ↓
    User clicks Allow → client$approve_tool(request_id)
             or Deny  → client$deny_tool(request_id, reason)
            ↓
    SDK sends control_response → CLI resumes or aborts the tool call

The CLI blocks indefinitely while waiting — no timeout. The streaming
loop continues polling during this time, so other messages (text deltas
from the response *before* the tool call) are still delivered.

## Why message-driven over `on_tool_request` callback?

An earlier approach used an `on_tool_request` callback with a `resolve`
closure. The message-driven pattern is preferred because:

- **Interrupt works during approval**: the same `interrupt_flag` check
  runs at the top of every loop iteration, so pressing ESC while the
  modal is open sends `deny_tool` and then `interrupt()`.
- **No extra state machine**: approval state (`pending_id`) is a plain
  `reactiveVal`, updated from both the streaming coroutine and the
  button observers.

## Complete App

``` r
library(shiny)
library(bslib)
library(shinychat)
library(ClaudeAgentSDK)
library(promises)
library(coro)

ui <- page_fillable(
  theme = bs_theme(bootswatch = "flatly"),
  tags$script(HTML("
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape')
        Shiny.setInputValue('esc', Math.random(), {priority: 'event'});
    });
  ")),
  card(
    card_header(
      div(
        class = "d-flex justify-content-between align-items-center",
        span("Claude — Tool Approval"),
        actionButton("interrupt_btn", "Interrupt", class = "btn-warning btn-sm")
      )
    ),
    chat_ui("chat", fill = TRUE,
            placeholder = "Try: 'Read the file /dev/null'")
  )
)

server <- function(input, output, session) {

  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns                   = 5L,
    # Required: routes can_use_tool requests through the message stream
    permission_prompt_tool_name = "stdio",
    include_partial_messages    = TRUE
  ))
  client$connect()
  onStop(function() client$disconnect())

  interrupt_flag <- reactiveVal(FALSE)
  pending_id     <- reactiveVal(NULL)   # request_id of the open modal, if any

  # ---- Approval buttons -------------------------------------------------------

  observeEvent(input$tool_allow, {
    rid <- pending_id()
    if (!is.null(rid)) {
      pending_id(NULL)
      removeModal()
      client$approve_tool(rid)
    }
  })

  observeEvent(input$tool_deny, {
    rid <- pending_id()
    if (!is.null(rid)) {
      pending_id(NULL)
      removeModal()
      client$deny_tool(rid, "Denied by user")
    }
  })

  # ---- Streaming coroutine ----------------------------------------------------

  do_stream <- coro::async(function(client, interrupt_flag, pending_id, session) {
    chunk_started <- FALSE
    interrupted   <- FALSE

    repeat {
      # Check interrupt at the top of every iteration
      if (!interrupted && shiny::isolate(interrupt_flag())) {
        interrupted <- TRUE
        # If a modal is open, deny the pending tool before interrupting
        rid <- shiny::isolate(pending_id())
        if (!is.null(rid)) {
          pending_id(NULL)
          removeModal(session = session)
          tryCatch(client$deny_tool(rid, "Interrupted"), error = function(e) NULL)
        }
        tryCatch(client$interrupt(), error = function(e) NULL)
        if (chunk_started) {
          chat_append_message("chat",
            list(role = "assistant", content = "\n\n_[Interrupted]_"),
            chunk = "end", session = session)
          chunk_started <- FALSE
        } else {
          chat_append_message("chat",
            list(role = "assistant", content = "_[Interrupted]_"),
            chunk = FALSE, session = session)
        }
      }

      msgs <- tryCatch(client$poll_messages(), error = function(e) list())

      if (length(msgs) == 0L) {
        await(promises::promise(function(resolve, reject) {
          later::later(function() resolve(TRUE), 0.05)
        }))
        next
      }

      drain_done <- FALSE
      for (msg in msgs) {
        await(promises::promise_resolve(TRUE))  # yield between messages

        # Drain mode after interrupt
        if (interrupted) {
          if (inherits(msg, "ResultMessage")) { drain_done <- TRUE; break }
          next
        }

        # ---- Tool approval request ----------------------------------------
        if (inherits(msg, "PermissionRequestMessage")) {
          # Close any open streaming chunk before showing the modal
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
            chunk_started <- FALSE
          }

          input_json <- jsonlite::toJSON(
            msg$tool_input, auto_unbox = TRUE, pretty = TRUE
          )

          # Show the tool call in the chat history
          chat_append_message("chat",
            list(role = "assistant", content = paste0(
              "\n\n**Tool request: `", msg$tool_name, "`**\n\n```json\n",
              input_json, "\n```\n"
            )),
            chunk = FALSE, session = session)

          # Store the request_id and open the approval modal
          pending_id(msg$request_id)
          showModal(modalDialog(
            title = paste("Allow tool:", msg$tool_name),
            tags$pre(input_json),
            footer = tagList(
              actionButton("tool_allow", "Allow", class = "btn-success"),
              actionButton("tool_deny",  "Deny",  class = "btn-danger")
            ),
            easyClose = FALSE
          ), session = session)
          next   # keep polling — modal is now open
        }

        # ---- Streaming text tokens ----------------------------------------
        if (inherits(msg, "StreamEvent") && is.list(msg$event)) {
          evt <- msg$event
          if (identical(evt$type, "content_block_delta") &&
              is.list(evt$delta) &&
              identical(evt$delta$type, "text_delta") &&
              !is.null(evt$delta$text)) {
            if (!chunk_started) {
              chunk_started <- TRUE
              chat_append_message("chat",
                list(role = "assistant", content = ""),
                chunk = "start", session = session)
            }
            chat_append_message("chat",
              list(role = "assistant", content = evt$delta$text),
              chunk = TRUE, session = session)
          }
        }

        # ---- Fallback: full AssistantMessage (non-streaming models) --------
        if (inherits(msg, "AssistantMessage") && !chunk_started) {
          for (blk in msg$content) {
            if (inherits(blk, "TextBlock") && nzchar(blk$text)) {
              chat_append_message("chat",
                list(role = "assistant", content = blk$text),
                chunk = FALSE, session = session)
            }
          }
        }

        # ---- Done ---------------------------------------------------------
        if (inherits(msg, "ResultMessage")) {
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
          }
          return("done")
        }
      }

      if (drain_done) break
    }

    "done"
  })

  stream_task <- ExtendedTask$new(function(user_input) {
    client$send(user_input)
    do_stream(client, interrupt_flag, pending_id, session)
  })

  observeEvent(input$chat_user_input, {
    if (stream_task$status() == "running") return()
    interrupt_flag(FALSE)
    stream_task$invoke(input$chat_user_input)
  })

  observeEvent(input$esc,           { if (stream_task$status() == "running") interrupt_flag(TRUE) })
  observeEvent(input$interrupt_btn, { if (stream_task$status() == "running") interrupt_flag(TRUE) })
}

shinyApp(ui, server)
```

## Testing the App

Start the app and send a prompt that triggers tool use:

- `"Read the file /dev/null"` — triggers `Read` tool
- `"List files in /tmp"` — triggers `Bash` tool

A modal dialog appears showing the tool name and JSON input. Click
**Allow** to let Claude proceed, or **Deny** to block it. Press **ESC**
or the **Interrupt** button at any time to cancel the current operation.

## Key API Reference

| Call                                   | When to use                          |
|----------------------------------------|--------------------------------------|
| `client$approve_tool(request_id)`      | User clicked Allow                   |
| `client$deny_tool(request_id, reason)` | User clicked Deny                    |
| `client$interrupt()`                   | User interrupted the whole operation |
| `PermissionRequestMessage$request_id`  | ID to pass to approve/deny           |
| `PermissionRequestMessage$tool_name`   | Display to the user                  |
| `PermissionRequestMessage$tool_input`  | Show as JSON in the modal            |

## Running the Example

``` r
shiny::runApp("examples/15_shinychat_tool_approval_msgdriven.R")
```
