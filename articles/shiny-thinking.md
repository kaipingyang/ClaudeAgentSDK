# Shiny Integration: Streaming Thinking Cards

This article shows how to display Claude’s **extended thinking** as a
collapsible card that streams in real time, combined with tool approval
and reliable interrupt support. It is the most complete Shiny
integration pattern in the SDK.

## What this app does

- Streams `ThinkingBlock` content into a live collapsible card (spinner
  while thinking, “💡 Thought” when complete).
- Shows a tool-call card for each `ToolUseBlock`, updating the title as
  the JSON input streams in.
- Requires user approval via inline Allow / Deny buttons before each
  tool executes.
- Supports interrupt via ESC key or an Interrupt button at any point —
  including while a tool-approval dialog is pending.

## Two bugs fixed compared to a naive implementation

### 1. Shadow DOM: CSS selectors cannot pierce shinychat

`shinychat` renders its chat messages inside a shadow root. A call like
`document.querySelector('.sdk-thinking-card.thinking-active')` returns
`null` even when the element is present — the selector cannot cross the
shadow DOM boundary.

**Fix**: assign each thinking block a unique `card_id`. Use
`findInDom(id)`, which first tries `document.getElementById()` and, if
that fails, walks all shadow roots:

``` javascript
function findInDom(id) {
  var el = document.getElementById(id);
  if (el) return el;
  var hosts = document.querySelectorAll('*');
  for (var i = 0; i < hosts.length; i++) {
    if (hosts[i].shadowRoot) {
      var found = hosts[i].shadowRoot.getElementById(id);
      if (found) return found;
    }
  }
  return null;
}
```

For thinking card updates the app uses server-side
`operation = "replace"` via `chat_append_message()` instead of DOM
manipulation, which avoids the issue entirely — the server re-renders
the full card HTML and replaces it.

### 2. Message queue flooding delays `Shiny.bindAll()`

A burst of `chat_append_message()` calls (one per streamed token) floods
the Shiny message queue. `Shiny.bindAll()` was firing before the
approval buttons landed in the DOM, so the buttons were unresponsive.

**Fix**: increase the `setTimeout` in the `bindNewInputs` handler from
80 ms to 200 ms, giving the queue time to drain:

``` javascript
Shiny.addCustomMessageHandler('bindNewInputs', function(data) {
  setTimeout(function() {
    var el = findInDom(data.wrapId);
    if (el) Shiny.bindAll(el);
  }, 200);   // 200 ms lets the burst settle
});
```

## Architecture overview

    coro::async loop
      │
      ├─ StreamEvent / content_block_start (thinking)
      │    └─ chat_append_message(thinking_html(in_progress=TRUE))
      │
      ├─ StreamEvent / content_block_delta (thinking_delta)
      │    └─ accumulate thinking_buf
      │       every 100ms → chat_append_message(operation="replace")
      │
      ├─ StreamEvent / content_block_stop (thinking)
      │    └─ chat_append_message(thinking_html(in_progress=FALSE), operation="replace")
      │
      ├─ StreamEvent / text_delta → streaming text tokens
      │
      ├─ PermissionRequestMessage
      │    └─ render approval card + bindNewInputs (200ms)
      │       observeEvent(allow/deny) → client$approve_tool / client$deny_tool
      │
      └─ ResultMessage → return "done"

## Options

``` r
client <- ClaudeSDKClient$new(ClaudeAgentOptions(
  max_turns                   = 5L,
  permission_prompt_tool_name = "stdio",   # required for message-driven approval
  include_partial_messages    = TRUE       # enables StreamEvent token stream
  # To enable extended thinking, uncomment:
  # thinking = ThinkingConfigEnabled(budget_tokens = 5000L)
))
```

`permission_prompt_tool_name = "stdio"` routes `can_use_tool` CLI
requests through the message stream as `PermissionRequestMessage`
objects, so the
[`coro::async`](https://coro.r-lib.org/reference/async.html) loop
handles them like any other message.

## Complete App

``` r
library(shiny)
library(bslib)
library(shinychat)
library(ClaudeAgentSDK)
library(promises)
library(coro)
library(htmltools)

# ---- Helper: tool title --------------------------------------------------

.make_tool_title <- function(tool_name, input, max_len = 60L) {
  arg <- switch(tool_name,
    Bash      = input$command,
    Read      = input$file_path,
    Write     = input$file_path,
    Edit      = input$file_path,
    Glob      = input$pattern,
    Grep      = if (!is.null(input$pattern) && !is.null(input$path))
                  paste0(input$pattern, " in ", basename(input$path))
                else input$pattern,
    WebSearch = input$query,
    WebFetch  = input$url,
    {
      vals <- Filter(function(v) is.character(v) || is.numeric(v), input)
      if (length(vals) > 0L) as.character(vals[[1L]]) else NULL
    }
  )
  if (is.null(arg) || !nzchar(arg %||% "")) return(paste0(tool_name, "()"))
  if (nchar(arg) > max_len) arg <- paste0(substr(arg, 1L, max_len), "\u2026")
  paste0(tool_name, "(", arg, ")")
}

# ---- Helper: HTML cards --------------------------------------------------

.thinking_html <- function(text = "", in_progress = FALSE) {
  if (in_progress) {
    as.character(tags$details(
      open  = NA,
      class = "sdk-thinking-card thinking-active",
      tags$summary(class = "sdk-thinking-summary", "\U0001f4a1 Thinking"),
      if (nzchar(text)) tags$div(class = "sdk-thinking-body", text)
    ))
  } else {
    display <- if (nchar(text) > 3000L)
      paste0(substr(text, 1L, 3000L), "\n\u2026(truncated)")
    else text
    as.character(tags$details(
      class = "sdk-thinking-card",
      tags$summary(class = "sdk-thinking-summary", "\U0001f4a1 Thought"),
      tags$div(class = "sdk-thinking-body", display)
    ))
  }
}

.approval_card_html <- function(wrap_id, allow_id, deny_id,
                                tool_name, input_json) {
  as.character(div(
    id    = wrap_id,
    class = "sdk-approval-card pending",
    div(class = "sdk-approval-header",
        "\u23f3 Approval required: ", tags$code(tool_name)),
    tags$pre(class = "sdk-approval-args", input_json),
    div(class = "sdk-approval-btns",
        actionButton(allow_id, "\u2714 Allow", class = "btn-success btn-sm"),
        actionButton(deny_id,  "\u2716 Deny",  class = "btn-danger btn-sm"))
  ))
}

# ---- UI ------------------------------------------------------------------

ui <- page_fillable(
  theme = bs_theme(bootswatch = "flatly"),
  tags$style(HTML("
    .sdk-thinking-card {
      margin: 4px 0; border-left: 3px solid #6c757d;
      background: #f8f9fa; border-radius: 4px; font-size: 0.88em;
    }
    .sdk-thinking-summary { padding: 6px 10px; cursor: pointer; color: #495057;
      font-style: italic; list-style: none;
      display: flex; align-items: center; gap: 6px; }
    .sdk-thinking-body { padding: 8px 12px; white-space: pre-wrap;
      font-family: monospace; font-size: 0.9em; color: #555; }
    @keyframes sdk-spin { to { transform: rotate(360deg); } }
    .sdk-thinking-card.thinking-active .sdk-thinking-summary::after {
      content: ''; display: inline-block;
      width: 11px; height: 11px; flex-shrink: 0;
      border: 2px solid #ced4da; border-top-color: #6c757d;
      border-radius: 50%; animation: sdk-spin 1.4s linear infinite; }
    .sdk-approval-card { margin: 4px 0; border-radius: 6px;
      font-size: 0.9em; border: 1px solid #f0ad4e; }
    .sdk-approval-card.pending { background: #fff8f0; }
    .sdk-approval-card.decided.allow {
      background: #d4edda; border-color: #28a745;
      padding: 8px 14px; color: #155724; font-weight: 600; }
    .sdk-approval-card.decided.deny {
      background: #f8d7da; border-color: #dc3545;
      padding: 8px 14px; color: #721c24; font-weight: 600; }
    .sdk-approval-header { padding: 8px 14px 4px; font-weight: 600; color: #856404; }
    .sdk-approval-args { margin: 4px 14px; font-size: 0.82em;
      max-height: 100px; overflow-y: auto; }
    .sdk-approval-btns { padding: 6px 14px 10px; display: flex; gap: 8px; }
  ")),
  tags$script(HTML("
    /* ESC key interrupt */
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape')
        Shiny.setInputValue('esc', Math.random(), {priority: 'event'});
    });

    /* Shadow DOM-aware lookup */
    function findInDom(id) {
      var el = document.getElementById(id);
      if (el) return el;
      var hosts = document.querySelectorAll('*');
      for (var i = 0; i < hosts.length; i++) {
        if (hosts[i].shadowRoot) {
          var found = hosts[i].shadowRoot.getElementById(id);
          if (found) return found;
        }
      }
      return null;
    }

    /* Bind approval buttons after 200ms so the message queue drains first */
    Shiny.addCustomMessageHandler('bindNewInputs', function(data) {
      setTimeout(function() {
        var el = findInDom(data.wrapId);
        if (el) Shiny.bindAll(el);
      }, 200);
    });

    /* Update approval card to resolved state */
    Shiny.addCustomMessageHandler('resolveApproval', function(data) {
      var el = findInDom(data.wrapId);
      if (!el) return;
      el.classList.remove('pending');
      el.classList.add('decided', data.state);
      var hdr = el.querySelector('.sdk-approval-header');
      if (hdr) {
        var icons = {allow: '\u2705', deny: '\u274c', interrupted: '\u26a1'};
        var verbs = {allow: 'Allowed', deny: 'Denied', interrupted: 'Interrupted'};
        hdr.innerHTML = (icons[data.state] || '') + ' ' +
                        (verbs[data.state] || data.state) +
                        (data.toolName ? ': <code>' + data.toolName + '</code>' : '');
      }
      var args = el.querySelector('.sdk-approval-args');
      if (args) args.style.display = 'none';
      var btns = el.querySelector('.sdk-approval-btns');
      if (btns) btns.style.display = 'none';
    });
  ")),
  card(
    card_header(
      div(
        class = "d-flex justify-content-between align-items-center",
        span("Streaming Thinking + Tool Cards + Approval"),
        actionButton("interrupt_btn", "Interrupt", class = "btn-warning btn-sm")
      )
    ),
    chat_ui("chat", fill = TRUE,
            placeholder = "Try: 'Run `echo hello world`'")
  )
)

# ---- Server --------------------------------------------------------------

server <- function(input, output, session) {

  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns                   = 5L,
    permission_prompt_tool_name = "stdio",
    include_partial_messages    = TRUE
    # thinking = ThinkingConfigEnabled(budget_tokens = 5000L)
  ))
  client$connect()
  onStop(function() client$disconnect())

  interrupt_flag <- reactiveVal(FALSE)
  pending_id     <- reactiveVal(NULL)

  do_stream <- coro::async(function(client, interrupt_flag,
                                    pending_id, session) {
    chunk_started          <- FALSE
    text_streamed          <- FALSE
    interrupted            <- FALSE
    is_thinking            <- FALSE
    thinking_buf           <- ""
    last_thinking_render_t <- -Inf
    cur_block_type         <- ""
    cur_tool_id            <- NULL
    pending_tname          <- NULL
    tool_bufs              <- new.env(hash = TRUE, parent = emptyenv())
    tool_names_env         <- new.env(hash = TRUE, parent = emptyenv())
    tool_titles_env        <- new.env(hash = TRUE, parent = emptyenv())
    approved_tool_ids      <- new.env(hash = TRUE, parent = emptyenv())

    repeat {
      if (!interrupted && shiny::isolate(interrupt_flag())) {
        interrupted <- TRUE
        rid <- shiny::isolate(pending_id())
        if (!is.null(rid)) {
          wrap_id <- paste0("aprv_", gsub("[^a-zA-Z0-9]", "_", rid))
          session$sendCustomMessage("resolveApproval",
            list(wrapId = wrap_id, state = "interrupted",
                 toolName = pending_tname %||% ""))
          pending_id(NULL)
          pending_tname <- NULL
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
        await(promises::promise_resolve(TRUE))

        if (interrupted) {
          if (inherits(msg, "ResultMessage")) { drain_done <- TRUE; break }
          next
        }

        # ---- StreamEvent -------------------------------------------------
        if (inherits(msg, "StreamEvent") && is.list(msg$event)) {
          evt   <- msg$event
          etype <- evt$type %||% ""

          if (identical(etype, "content_block_start")) {
            blk            <- evt$content_block %||% list()
            cur_block_type <- blk$type %||% ""

            if (identical(cur_block_type, "thinking")) {
              is_thinking            <- TRUE
              thinking_buf           <- ""
              last_thinking_render_t <- proc.time()[["elapsed"]]
              chat_append_message("chat",
                list(role = "assistant",
                     content = .thinking_html(in_progress = TRUE)),
                chunk = FALSE, session = session)
            }

            if (identical(cur_block_type, "tool_use") && !is.null(blk$id)) {
              if (chunk_started) {
                chat_append_message("chat",
                  list(role = "assistant", content = ""),
                  chunk = "end", session = session)
                chunk_started <- FALSE
              }
              cur_tool_id               <- blk$id
              tool_names_env[[blk$id]]  <- blk$name %||% "unknown"
              tool_bufs[[blk$id]]       <- ""
            }
          }

          if (identical(etype, "content_block_delta")) {
            delta <- evt$delta %||% list()

            if (identical(delta$type, "text_delta") && !is.null(delta$text)) {
              if (!chunk_started) {
                chunk_started <- TRUE
                text_streamed <- TRUE
                chat_append_message("chat",
                  list(role = "assistant", content = ""),
                  chunk = "start", session = session)
              }
              chat_append_message("chat",
                list(role = "assistant", content = delta$text),
                chunk = TRUE, session = session)
            }

            if (identical(delta$type, "thinking_delta") &&
                !is.null(delta$thinking)) {
              thinking_buf <- paste0(thinking_buf, delta$thinking)
              now_t <- proc.time()[["elapsed"]]
              if (now_t - last_thinking_render_t >= 0.1) {
                last_thinking_render_t <- now_t
                chat_append_message("chat",
                  list(role = "assistant",
                       content = .thinking_html(thinking_buf, in_progress = TRUE)),
                  chunk = TRUE, operation = "replace", session = session)
              }
            }

            if (identical(delta$type, "input_json_delta") &&
                !is.null(cur_tool_id)) {
              tid              <- cur_tool_id
              tool_bufs[[tid]] <- paste0(tool_bufs[[tid]] %||% "",
                                         delta$partial_json %||% "")
            }
          }

          if (identical(etype, "content_block_stop")) {
            if (identical(cur_block_type, "text") && chunk_started) {
              chat_append_message("chat",
                list(role = "assistant", content = ""),
                chunk = "end", session = session)
              chunk_started <- FALSE
            }

            if (identical(cur_block_type, "thinking") && is_thinking) {
              chat_append_message("chat",
                list(role = "assistant",
                     content = .thinking_html(thinking_buf, in_progress = FALSE)),
                chunk = TRUE, operation = "replace", session = session)
              is_thinking            <- FALSE
              thinking_buf           <- ""
              last_thinking_render_t <- -Inf
            }

            if (identical(cur_block_type, "tool_use") && !is.null(cur_tool_id)) {
              tid    <- cur_tool_id
              tname  <- tool_names_env[[tid]] %||% "unknown"
              tjson  <- tool_bufs[[tid]] %||% "{}"
              tparsed <- tryCatch(
                jsonlite::fromJSON(tjson, simplifyVector = FALSE),
                error = function(e) list()
              )
              ttitle <- .make_tool_title(tname, tparsed)
              tool_titles_env[[tid]] <- ttitle
              cur_tool_id            <- NULL
            }
            cur_block_type <- ""
          }
        }

        # ---- PermissionRequestMessage ------------------------------------
        if (inherits(msg, "PermissionRequestMessage")) {
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
            chunk_started <- FALSE
          }

          rid      <- msg$request_id
          tname    <- msg$tool_name
          suffix   <- gsub("[^a-zA-Z0-9]", "_", rid)
          allow_id <- paste0("allow_", suffix)
          deny_id  <- paste0("deny_",  suffix)
          wrap_id  <- paste0("aprv_",  suffix)
          input_json <- jsonlite::toJSON(
            msg$tool_input, auto_unbox = TRUE, pretty = TRUE)

          if (!is.null(msg$tool_use_id)) {
            tid <- msg$tool_use_id
            approved_tool_ids[[tid]] <- TRUE
            if (is.null(tool_names_env[[tid]])) tool_names_env[[tid]] <- tname
          }

          chat_append_message("chat",
            list(role  = "assistant",
                 content = .approval_card_html(
                   wrap_id, allow_id, deny_id, tname, input_json)),
            chunk = FALSE, session = session)
          session$sendCustomMessage("bindNewInputs", list(wrapId = wrap_id))

          pending_id(rid)
          pending_tname <- tname

          observeEvent(input[[allow_id]], {
            session$sendCustomMessage("resolveApproval",
              list(wrapId = wrap_id, state = "allow", toolName = tname))
            pending_id(NULL)
            client$approve_tool(rid)
          }, once = TRUE, ignoreNULL = TRUE, ignoreInit = TRUE)

          observeEvent(input[[deny_id]], {
            session$sendCustomMessage("resolveApproval",
              list(wrapId = wrap_id, state = "deny", toolName = tname))
            pending_id(NULL)
            client$deny_tool(rid, "Denied by user")
          }, once = TRUE, ignoreNULL = TRUE, ignoreInit = TRUE)

          next
        }

        # ---- UserMessage (tool results) ----------------------------------
        if (inherits(msg, "UserMessage")) {
          for (blk in msg$content) {
            if (inherits(blk, "ToolResultBlock")) {
              tid    <- blk$tool_use_id
              tname  <- tool_names_env[[tid]] %||% "unknown"
              ttitle <- tool_titles_env[[tid]]
              cstr   <- if (is.character(blk$content)) blk$content else
                tryCatch(jsonlite::toJSON(blk$content, auto_unbox = TRUE),
                         error = function(e) "")
              chat_append_message("chat",
                list(role = "assistant",
                     content = paste0("\n**", ttitle %||% tname,
                                      if (isTRUE(blk$is_error)) " ❌" else " ✅",
                                      "**\n\n```\n", cstr, "\n```\n")),
                chunk = FALSE, session = session)
            }
          }
        }

        # ---- AssistantMessage (fallback) ---------------------------------
        if (inherits(msg, "AssistantMessage") && !chunk_started) {
          for (blk in msg$content) {
            if (inherits(blk, "TextBlock") &&
                nzchar(blk$text %||% "") && !text_streamed) {
              chat_append_message("chat",
                list(role = "assistant", content = blk$text),
                chunk = FALSE, session = session)
            }
          }
        }

        # ---- ResultMessage -----------------------------------------------
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

``` r
shiny::runApp("examples/20_shinychat_streaming_thinking.R")
```

Test scenarios:

| Prompt                                               | What to observe                                         |
|------------------------------------------------------|---------------------------------------------------------|
| `"What is 17 × 23?"`                                 | No thinking (model decides)                             |
| Uncomment `ThinkingConfigEnabled`, ask a reasoning Q | Spinner card while thinking → collapses to “💡 Thought” |
| `"Run \`echo hello world\`“\`                        | Approval card with Allow / Deny buttons                 |
| Enable thinking + ask a tool-use question            | Both thinking card and approval card                    |
| Press **ESC** during thinking                        | “\[Interrupted\]” appended, spinner removed             |
| Press **ESC** while approval card pending            | Card changes to “⚡ Interrupted”                        |

## Key API Reference

| Call / Field                                                | Purpose                                                    |
|-------------------------------------------------------------|------------------------------------------------------------|
| `ClaudeAgentOptions(include_partial_messages = TRUE)`       | Enable `StreamEvent` token stream                          |
| `ClaudeAgentOptions(permission_prompt_tool_name = "stdio")` | Route tool approval through message stream                 |
| `ThinkingConfigEnabled(budget_tokens = N)`                  | Enable extended thinking with token budget                 |
| `client$poll_messages()`                                    | Non-blocking poll; returns list of pending messages        |
| `client$approve_tool(request_id)`                           | Send `allow` control response to CLI                       |
| `client$deny_tool(request_id, reason)`                      | Send `deny` control response to CLI                        |
| `client$interrupt()`                                        | Send interrupt signal to CLI subprocess                    |
| `chat_append_message(..., operation = "replace")`           | Replace last message in-place (used for live card updates) |
