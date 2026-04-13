# examples/20_shinychat_streaming_thinking.R
# =========================================================================
# 流式 thinking 卡片（基于 example 19，修复 streaming thinking 的两个问题）
# =========================================================================
#
# example 19（cd6c0fa）的 streaming thinking 版本存在两个 bug：
#
#   1. finalizeThinking 用 `.sdk-thinking-card.thinking-active` CSS 选择器
#      查找元素，但该元素在 shinychat 的 shadow DOM 内，queryInDom() 的
#      querySelector 无法穿透 → 卡片一直显示转圈，无法变为 "💡 Thought"
#
#   2. 大量 appendThinking 消息堵塞 Shiny 消息队列，bindNewInputs 被延迟，
#      审批按钮 Shiny.bindAll() 失败 → 审批按钮无响应，工具被绕过执行
#
# 修复方案：
#   - 给每个 thinking 块分配唯一 card_id / body_id
#   - JS 改用 findInDom(id)（按 ID 查找，已验证能穿透 shadow DOM）
#   - bindNewInputs 的 setTimeout 延迟从 80ms 增加到 200ms，给消息队列
#     充分时间清空后再执行 Shiny.bindAll()
#
# 运行：
#   shiny::runApp("examples/20_shinychat_streaming_thinking.R")
#
# 测试提示：
#   流式 thinking : 取消注释 ThinkingConfigEnabled 行，问需要推理的问题
#   审批流程      : 问 "Run `echo hello world`"
#   同时测试      : 开启 thinking 后问需要工具的问题
#   打断          : 思考中按 Esc
#
# =========================================================================

library(shiny)
library(bslib)
library(shinychat)
library(ClaudeAgentSDK)
library(promises)
library(coro)
library(htmltools)

# ---- Helper: 工具标题 ----------------------------------------------------

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

.try_partial_title <- function(tool_name, buffer) {
  if (!nzchar(buffer %||% "")) return(NULL)
  key <- switch(tool_name,
    Bash = "command", Read = "file_path", Write = "file_path",
    Edit = "file_path", Glob = "pattern", Grep = "pattern",
    WebSearch = "query", WebFetch = "url", NULL
  )
  if (is.null(key)) return(NULL)
  m <- regexec(paste0('"', key, '"\\s*:\\s*"([^"]+)'), buffer, perl = TRUE)
  captures <- regmatches(buffer, m)[[1L]]
  if (length(captures) < 2L || !nzchar(captures[2L])) return(NULL)
  paste0(tool_name, "(", captures[2L], "\u2026)")
}

# ---- Helper: HTML 卡片 ---------------------------------------------------

# 修复版：card_id / body_id 分配唯一 ID，供 JS findInDom(id) 定位
.thinking_html <- function(card_id, body_id, text = "", in_progress = FALSE) {
  if (in_progress) {
    as.character(tags$details(
      id    = card_id,
      class = "sdk-thinking-card thinking-active",
      tags$summary(class = "sdk-thinking-summary", "\U0001f4a1 Thinking"),
      tags$div(id = body_id, class = "sdk-thinking-body")
    ))
  } else {
    display <- if (nchar(text) > 3000L)
      paste0(substr(text, 1L, 3000L), "\n\u2026(truncated)")
    else text
    as.character(tags$details(
      id    = card_id,
      class = "sdk-thinking-card",
      tags$summary(class = "sdk-thinking-summary", "\U0001f4a1 Thought"),
      tags$div(id = body_id, class = "sdk-thinking-body", display)
    ))
  }
}

.tool_req_html <- function(tool_id, tool_name,
                            tool_title = NULL, args = "{}") {
  as.character(htmltools::tag("shiny-tool-request", list(
    `request-id` = tool_id,
    `tool-name`  = tool_name,
    `tool-title` = tool_title %||% paste0(tool_name, "(\u2026)"),
    arguments    = args
  )))
}

.tool_res_html <- function(tool_id, tool_name, tool_title,
                            result_str, is_error) {
  as.character(htmltools::tag("shiny-tool-result", list(
    `request-id` = tool_id,
    `tool-name`  = tool_name,
    `tool-title` = tool_title %||% tool_name,
    status       = if (isTRUE(is_error)) "error" else "success",
    value        = result_str,
    `value-type` = "code"
  )))
}

.plain_tool_req_html <- function(tool_name, tool_title) {
  as.character(div(
    class = "sdk-tool-req-info",
    style = "font-size: 0.85em; color: #6c757d; padding: 2px 4px;",
    "\U0001f527 ",
    tags$code(tool_title %||% paste0(tool_name, "()"))
  ))
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
        actionButton(allow_id, "\u2714 Allow",
                     class = "btn-success btn-sm"),
        actionButton(deny_id,  "\u2716 Deny",
                     class = "btn-danger btn-sm"))
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
    .sdk-thinking-summary {
      padding: 6px 10px; cursor: pointer; color: #495057;
      font-style: italic; list-style: none;
      display: flex; align-items: center; gap: 6px;
    }
    .sdk-thinking-body {
      padding: 8px 12px; white-space: pre-wrap;
      font-family: monospace; font-size: 0.9em; color: #555;
    }
    @keyframes sdk-spin { to { transform: rotate(360deg); } }
    .sdk-thinking-card.thinking-active .sdk-thinking-summary::after {
      content: ''; display: inline-block;
      width: 11px; height: 11px; flex-shrink: 0;
      border: 2px solid #ced4da; border-top-color: #6c757d;
      border-radius: 50%; animation: sdk-spin 0.75s linear infinite;
    }
    .sdk-approval-card {
      margin: 4px 0; border-radius: 6px; font-size: 0.9em;
      border: 1px solid #f0ad4e;
    }
    .sdk-approval-card.pending   { background: #fff8f0; }
    .sdk-approval-card.decided.allow {
      background: #d4edda; border-color: #28a745;
      padding: 8px 14px; color: #155724; font-weight: 600;
    }
    .sdk-approval-card.decided.deny {
      background: #f8d7da; border-color: #dc3545;
      padding: 8px 14px; color: #721c24; font-weight: 600;
    }
    .sdk-approval-card.decided.interrupted {
      background: #fff3cd; border-color: #ffc107;
      padding: 8px 14px; color: #856404; font-weight: 600;
    }
    .sdk-approval-header { padding: 8px 14px 4px; font-weight: 600; color: #856404; }
    .sdk-approval-args   { margin: 4px 14px; font-size: 0.82em; max-height: 100px; overflow-y: auto; }
    .sdk-approval-btns   { padding: 6px 14px 10px; display: flex; gap: 8px; }
  ")),
  tags$script(HTML("
    /* ESC 键打断 */
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape')
        Shiny.setInputValue('esc', Math.random(), {priority: 'event'});
    });

    /* shadow DOM 感知：按 ID 查找（已验证能穿透 shinychat shadow root）*/
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

    /* 流式追加 thinking 内容：按 body_id 精确定位，O(1) textContent 追加 */
    Shiny.addCustomMessageHandler('appendThinking', function(data) {
      var body = findInDom(data.bodyId);
      if (body) body.textContent += data.text;
    });

    /* 思考结束：按 card_id 定位，移除转圈，改标题，可选截断 */
    Shiny.addCustomMessageHandler('finalizeThinking', function(data) {
      var card = findInDom(data.cardId);
      if (!card) return;
      card.classList.remove('thinking-active');
      var summary = card.querySelector('.sdk-thinking-summary');
      if (summary) summary.textContent = '\ud83d\udca1 Thought';
      if (data.truncated) {
        var body = findInDom(data.bodyId);
        if (body) body.textContent =
          body.textContent.substring(0, 3000) + '\n\u2026(truncated)';
      }
    });

    /* 绑定审批按钮：延迟 200ms 等消息队列清空后再 bindAll */
    Shiny.addCustomMessageHandler('bindNewInputs', function(data) {
      setTimeout(function() {
        var el = findInDom(data.wrapId);
        if (el) Shiny.bindAll(el);
      }, 200);
    });

    /* 审批卡片原地更新为已决状态 */
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
                        (verbs[data.state]  || data.state) +
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
        span("流式 Thinking + 工具卡片 + 审批"),
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
    # 如需 extended thinking，取消注释：
    # thinking = ThinkingConfigEnabled(budget_tokens = 5000L)
  ))
  client$connect()
  onStop(function() client$disconnect())

  interrupt_flag <- reactiveVal(FALSE)
  pending_id     <- reactiveVal(NULL)

  do_stream <- coro::async(function(client, interrupt_flag,
                                    pending_id, session) {
    chunk_started   <- FALSE
    interrupted     <- FALSE
    is_thinking     <- FALSE
    thinking_buf    <- ""
    thinking_card_id <- NULL   # 当前 thinking 块的唯一 card ID
    thinking_body_id <- NULL   # 当前 thinking 块的唯一 body ID
    cur_block_type  <- ""
    cur_tool_id     <- NULL
    pending_tname   <- NULL
    tool_bufs         <- new.env(hash = TRUE, parent = emptyenv())
    tool_names_env    <- new.env(hash = TRUE, parent = emptyenv())
    tool_titles_env   <- new.env(hash = TRUE, parent = emptyenv())
    early_shown       <- new.env(hash = TRUE, parent = emptyenv())
    approved_tool_ids <- new.env(hash = TRUE, parent = emptyenv())

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

        # ==============================================================
        # StreamEvent
        # ==============================================================
        if (inherits(msg, "StreamEvent") && is.list(msg$event)) {
          evt   <- msg$event
          etype <- evt$type %||% ""

          if (identical(etype, "content_block_start")) {
            blk <- evt$content_block %||% list()
            cur_block_type <- blk$type %||% ""

            if (identical(cur_block_type, "tool_use")) {
              if (chunk_started) {
                chat_append_message("chat",
                  list(role = "assistant", content = ""),
                  chunk = "end", session = session)
                chunk_started <- FALSE
              }
              if (!is.null(blk$id)) {
                cur_tool_id <- blk$id
                tool_names_env[[blk$id]] <- blk$name %||% "unknown"
                tool_bufs[[blk$id]]      <- ""
                early_shown[[blk$id]]    <- FALSE
                chat_append_message("chat",
                  list(role = "assistant",
                       content = .tool_req_html(
                         blk$id, blk$name %||% "unknown")),
                  chunk = FALSE, session = session)
              }
            }

            if (identical(cur_block_type, "thinking")) {
              is_thinking      <- TRUE
              thinking_buf     <- ""
              # 唯一 ID（毫秒时间戳），JS 用 findInDom 定位，无需 class 选择器
              ts               <- as.character(as.integer(as.numeric(Sys.time()) * 1000))
              thinking_card_id <- paste0("thk_", ts)
              thinking_body_id <- paste0("thk_body_", ts)
              chat_append_message("chat",
                list(role = "assistant",
                     content = .thinking_html(
                       thinking_card_id, thinking_body_id,
                       in_progress = TRUE)),
                chunk = FALSE, session = session)
            }
          }

          if (identical(etype, "content_block_delta")) {
            delta <- evt$delta %||% list()

            if (identical(delta$type, "text_delta") && !is.null(delta$text)) {
              if (!chunk_started) {
                chunk_started <- TRUE
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
              # 流式追加：按 body_id 精确定位（findInDom 穿透 shadow DOM）
              session$sendCustomMessage("appendThinking",
                list(bodyId = thinking_body_id, text = delta$thinking))
            }

            if (identical(delta$type, "input_json_delta") &&
                !is.null(cur_tool_id)) {
              tid <- cur_tool_id
              tool_bufs[[tid]] <- paste0(
                tool_bufs[[tid]] %||% "", delta$partial_json %||% "")
              if (!isTRUE(early_shown[[tid]])) {
                tname_e <- tool_names_env[[tid]] %||% "unknown"
                et <- .try_partial_title(tname_e, tool_bufs[[tid]])
                if (!is.null(et)) {
                  early_shown[[tid]] <- TRUE
                  chat_append_message("chat",
                    list(role = "assistant",
                         content = .tool_req_html(tid, tname_e, et)),
                    chunk = TRUE, operation = "replace",
                    session = session)
                }
              }
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
              # 思考结束：JS 按 card_id 定位，移除转圈 + 改标题 + 可选截断
              session$sendCustomMessage("finalizeThinking",
                list(cardId   = thinking_card_id,
                     bodyId   = thinking_body_id,
                     truncated = nchar(thinking_buf) > 3000L))
              is_thinking      <- FALSE
              thinking_buf     <- ""
              thinking_card_id <- NULL
              thinking_body_id <- NULL
            }

            if (identical(cur_block_type, "tool_use") &&
                !is.null(cur_tool_id)) {
              tid    <- cur_tool_id
              tname  <- tool_names_env[[tid]] %||% "unknown"
              tjson  <- tool_bufs[[tid]] %||% "{}"
              tparsed <- tryCatch(
                jsonlite::fromJSON(tjson, simplifyVector = FALSE),
                error = function(e) list()
              )
              ttitle <- .make_tool_title(tname, tparsed)
              tool_titles_env[[tid]] <- ttitle
              chat_append_message("chat",
                list(role = "assistant",
                     content = .tool_req_html(tid, tname, ttitle, tjson)),
                chunk = TRUE, operation = "replace",
                session = session)
              cur_tool_id <- NULL
            }
            cur_block_type <- ""
          }
        }

        # ==============================================================
        # PermissionRequestMessage
        # ==============================================================
        if (inherits(msg, "PermissionRequestMessage")) {
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
            chunk_started <- FALSE
          }

          rid    <- msg$request_id
          tname  <- msg$tool_name
          suffix <- gsub("[^a-zA-Z0-9]", "_", rid)
          allow_id <- paste0("allow_", suffix)
          deny_id  <- paste0("deny_",  suffix)
          wrap_id  <- paste0("aprv_",  suffix)
          input_json <- jsonlite::toJSON(
            msg$tool_input, auto_unbox = TRUE, pretty = TRUE)

          if (!is.null(msg$tool_use_id)) {
            tid <- msg$tool_use_id
            approved_tool_ids[[tid]] <- TRUE
            ttitle <- tool_titles_env[[tid]] %||% paste0(tname, "(\u2026)")
            chat_append_message("chat",
              list(role = "assistant",
                   content = .plain_tool_req_html(tname, ttitle)),
              chunk = TRUE, operation = "replace",
              session = session)
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

        # ==============================================================
        # UserMessage — 工具结果
        # ==============================================================
        if (inherits(msg, "UserMessage")) {
          for (blk in msg$content) {
            if (inherits(blk, "ToolResultBlock")) {
              tid    <- blk$tool_use_id
              tname  <- tool_names_env[[tid]] %||% "unknown"
              ttitle <- tool_titles_env[[tid]]
              if (is.character(blk$content)) {
                cstr <- blk$content
              } else {
                cstr <- tryCatch(
                  jsonlite::toJSON(blk$content, auto_unbox = TRUE),
                  error = function(e) "")
              }
              if (isTRUE(approved_tool_ids[[tid]])) {
                chat_append_message("chat",
                  list(role = "assistant",
                       content = .tool_res_html(
                         tid, tname, ttitle, cstr, blk$is_error)),
                  chunk = FALSE, session = session)
              } else {
                chat_append_message("chat",
                  list(role = "assistant",
                       content = .tool_res_html(
                         tid, tname, ttitle, cstr, blk$is_error)),
                  chunk = TRUE, operation = "replace",
                  session = session)
              }
            }
          }
        }

        # ==============================================================
        # AssistantMessage — 回退
        # ==============================================================
        if (inherits(msg, "AssistantMessage") && !chunk_started) {
          for (blk in msg$content) {
            if (inherits(blk, "TextBlock") && nzchar(blk$text %||% "")) {
              chat_append_message("chat",
                list(role = "assistant", content = blk$text),
                chunk = FALSE, session = session)
            }
            if (inherits(blk, "ToolUseBlock") &&
                is.null(tool_names_env[[blk$id]])) {
              tool_names_env[[blk$id]] <- blk$name
              ajson <- tryCatch(
                jsonlite::toJSON(blk$input %||% list(), auto_unbox = TRUE),
                error = function(e) "{}")
              atitle <- .make_tool_title(blk$name, blk$input %||% list())
              tool_titles_env[[blk$id]] <- atitle
              chat_append_message("chat",
                list(role = "assistant",
                     content = .tool_req_html(blk$id, blk$name, atitle, ajson)),
                chunk = FALSE, session = session)
            }
          }
        }

        # ==============================================================
        # ResultMessage
        # ==============================================================
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

  observeEvent(input$esc, {
    if (stream_task$status() == "running") interrupt_flag(TRUE)
  })

  observeEvent(input$interrupt_btn, {
    if (stream_task$status() == "running") interrupt_flag(TRUE)
  })
}

shinyApp(ui, server)
