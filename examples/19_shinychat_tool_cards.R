# examples/19_shinychat_tool_cards.R
# =========================================================================
# shinychat 原生工具卡片 + 思考块 + 打断 + 内联审批卡片
# =========================================================================
#
# 功能：
#   - <shiny-tool-request>  流式填充参数 + 早期标题更新
#   - <shiny-tool-result>   原地替换请求卡片（operation="replace"）
#   - <details> 思考块      extended thinking 可折叠展示
#   - 审批卡片              PermissionRequestMessage → 嵌入 chat 历史的
#                           审批卡片（含 Allow/Deny 按钮），决策后原地替换
#                           为已确认状态，永久留存在对话记录中
#   - 打断 + drain          Esc / Interrupt 按钮
#
# 审批机制：
#   1. PermissionRequestMessage 到达 → chat_append_message 追加审批卡片
#      卡片内嵌 Shiny actionButton（生成标准 HTML）
#   2. session$sendCustomMessage("bindNewInputs") → 浏览器调用
#      Shiny.bindAll() 激活按钮的 Shiny 输入绑定
#   3. 用户点击 Allow/Deny → observeEvent(input[[btn_id]], once=TRUE)
#      触发 → session$sendCustomMessage("resolveApproval") 原地替换卡片内容
#      为已决状态 → approve_tool / deny_tool
#   4. 打断时：同样发 resolveApproval 将审批卡片标记为 "Interrupted"
#
# 运行：
#   shiny::runApp("examples/19_shinychat_tool_cards.R")
#
# 测试提示：
#   工具卡片  : "Run `echo hello world`"
#   审批流程  : permission_prompt_tool_name = "stdio"（默认已启用）
#   thinking  : 取消注释 ClaudeAgentOptions 中的 thinking 配置行
#   打断      : 问一个长问题后立刻按 Esc
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

.thinking_html <- function(text) {
  display <- if (nchar(text) > 3000L)
    paste0(substr(text, 1L, 3000L), "\n\u2026(truncated)")
  else text
  as.character(tags$details(
    class = "sdk-thinking-card",
    tags$summary(class = "sdk-thinking-summary", "\U0001f4a1 Thinking\u2026"),
    tags$div(class = "sdk-thinking-body", display)
  ))
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

# 工具请求占位（纯 HTML，不含 <shiny-tool-request>）
# 用于在 PermissionRequestMessage 时替换 M2，防止 shiny-tool-request-hide
# 将 M2 变成空白气泡（该事件只隐藏内层元素，不隐藏 <shiny-chat-message> 容器）
.plain_tool_req_html <- function(tool_name, tool_title) {
  as.character(div(
    class = "sdk-tool-req-info",
    style = paste(
      "font-size: 0.85em; color: #6c757d;",
      "padding: 2px 4px;"
    ),
    "\U0001f527 ",
    tags$code(tool_title %||% paste0(tool_name, "()"))
  ))
}

# 审批卡片：嵌入 Shiny actionButton，由 Shiny.bindAll() 激活
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
    /* 思考卡片 */
    .sdk-thinking-card {
      margin: 4px 0; border-left: 3px solid #6c757d;
      background: #f8f9fa; border-radius: 4px; font-size: 0.88em;
    }
    .sdk-thinking-summary {
      padding: 6px 10px; cursor: pointer; color: #495057;
      font-style: italic; list-style: none;
    }
    .sdk-thinking-body {
      padding: 8px 12px; white-space: pre-wrap;
      font-family: monospace; font-size: 0.9em; color: #555;
    }
    /* 审批卡片 */
    .sdk-approval-card {
      margin: 4px 0; border-radius: 6px; font-size: 0.9em;
      border: 1px solid #f0ad4e;
    }
    .sdk-approval-card.pending {
      background: #fff8f0;
    }
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
    .sdk-approval-header {
      padding: 8px 14px 4px; font-weight: 600; color: #856404;
    }
    .sdk-approval-args {
      margin: 4px 14px; font-size: 0.82em;
      max-height: 100px; overflow-y: auto;
    }
    .sdk-approval-btns {
      padding: 6px 14px 10px; display: flex; gap: 8px;
    }
  ")),
  tags$script(HTML("
    /* ESC 键打断 */
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape')
        Shiny.setInputValue('esc', Math.random(), {priority: 'event'});
    });

    /* shadow DOM 感知的元素查找：先在顶层 document 找，再遍历各 shadowRoot */
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

    /* 绑定 chat 中动态插入的 Shiny 输入（审批按钮） */
    Shiny.addCustomMessageHandler('bindNewInputs', function(data) {
      setTimeout(function() {
        var el = findInDom(data.wrapId);
        if (el) { Shiny.bindAll(el); }
      }, 80);
    });

    /* 原地更新审批卡片为已决状态（改 class、更新 header、隐藏按钮和参数）*/
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
        span("工具卡片 + 思考块 + 内联审批"),
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
  pending_id     <- reactiveVal(NULL)   # 当前待审批的 request_id

  # ---- coro::async 流式函数 -----------------------------------------------

  do_stream <- coro::async(function(client, interrupt_flag,
                                    pending_id, session) {
    # 局部可变状态
    chunk_started   <- FALSE
    interrupted     <- FALSE
    is_thinking     <- FALSE
    thinking_buf    <- ""
    cur_block_type  <- ""
    cur_tool_id     <- NULL
    pending_tname     <- NULL   # 当前待审批的工具名（供打断时更新卡片）
    tool_bufs         <- new.env(hash = TRUE, parent = emptyenv())
    tool_names_env    <- new.env(hash = TRUE, parent = emptyenv())
    tool_titles_env   <- new.env(hash = TRUE, parent = emptyenv())
    early_shown       <- new.env(hash = TRUE, parent = emptyenv())
    # 记录经过审批的 tool_use_id：这些工具的结果必须用 chunk=FALSE
    # 追加为新消息，而不能用 operation="replace"（否则会替换审批卡）
    approved_tool_ids <- new.env(hash = TRUE, parent = emptyenv())

    repeat {
      # ---- 循环顶部检测打断 ----
      if (!interrupted && shiny::isolate(interrupt_flag())) {
        interrupted <- TRUE
        rid <- shiny::isolate(pending_id())
        if (!is.null(rid)) {
          # 更新审批卡片为 Interrupted 状态
          wrap_id <- paste0("aprv_", gsub("[^a-zA-Z0-9]", "_", rid))
          session$sendCustomMessage("resolveApproval",
            list(wrapId    = wrap_id,
                 state     = "interrupted",
                 toolName  = pending_tname %||% ""))
          pending_id(NULL)
          pending_tname <- NULL
          tryCatch(client$deny_tool(rid, "Interrupted"),
                   error = function(e) NULL)
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

        # ---- Drain 模式 ----
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

          # content_block_start
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
              is_thinking  <- TRUE
              thinking_buf <- ""
              chat_append_message("chat",
                list(role = "assistant",
                     content = .thinking_html("...")),
                chunk = FALSE, session = session)
            }
          }

          # content_block_delta
          if (identical(etype, "content_block_delta")) {
            delta <- evt$delta %||% list()

            if (identical(delta$type, "text_delta") &&
                !is.null(delta$text)) {
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

          # content_block_stop
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
                     content = .thinking_html(thinking_buf)),
                chunk = TRUE, operation = "replace",
                session = session)
              is_thinking  <- FALSE
              thinking_buf <- ""
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
        # PermissionRequestMessage → 内联审批卡片（含 Allow/Deny 按钮）
        # ==============================================================
        if (inherits(msg, "PermissionRequestMessage")) {
          # 关闭进行中的文本流（避免产生空白气泡）
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

          # 处理 tool_use_id：
          #   1. 标记为"已审批"——其结果消息须用 chunk=FALSE 追加（不能
          #      用 operation="replace"，否则会替换审批卡而非工具请求卡）
          #   2. 将 M2（<shiny-tool-request>）替换为纯 HTML div：
          #      shiny-tool-request-hide 事件只隐藏 `.shiny-tool-request`
          #      内部元素，但 <shiny-chat-message> 容器留在 DOM，变成空白
          #      气泡。替换为纯 div 后，事件无法选中它，M2 保持可见。
          #      （此时 M2 仍是最后一条消息，operation="replace" 定位准确）
          if (!is.null(msg$tool_use_id)) {
            tid <- msg$tool_use_id
            approved_tool_ids[[tid]] <- TRUE
            ttitle <- tool_titles_env[[tid]] %||%
                        paste0(tname, "(\u2026)")
            chat_append_message("chat",
              list(role = "assistant",
                   content = .plain_tool_req_html(tname, ttitle)),
              chunk = TRUE, operation = "replace",
              session = session)
          }

          # 追加审批卡片到 chat 历史
          chat_append_message("chat",
            list(role  = "assistant",
                 content = .approval_card_html(
                   wrap_id, allow_id, deny_id, tname, input_json)),
            chunk = FALSE, session = session)

          # 激活卡片内的 Shiny 按钮（bindAll 在 DOM 渲染后执行）
          session$sendCustomMessage("bindNewInputs",
                                    list(wrapId = wrap_id))

          pending_id(rid)
          pending_tname <- tname

          # Allow 按钮（一次性 observer，关闭后自动注销）
          observeEvent(input[[allow_id]], {
            session$sendCustomMessage("resolveApproval",
              list(wrapId = wrap_id, state = "allow", toolName = tname))
            pending_id(NULL)
            client$approve_tool(rid)
          }, once = TRUE, ignoreNULL = TRUE, ignoreInit = TRUE)

          # Deny 按钮
          observeEvent(input[[deny_id]], {
            session$sendCustomMessage("resolveApproval",
              list(wrapId = wrap_id, state = "deny", toolName = tname))
            pending_id(NULL)
            client$deny_tool(rid, "Denied by user")
          }, once = TRUE, ignoreNULL = TRUE, ignoreInit = TRUE)

          next
        }

        # ==============================================================
        # UserMessage — 工具结果替换请求卡片
        # ==============================================================
        if (inherits(msg, "UserMessage")) {
          for (blk in msg$content) {
            if (inherits(blk, "ToolResultBlock")) {
              tid   <- blk$tool_use_id
              tname <- tool_names_env[[tid]] %||% "unknown"
              ttitle <- tool_titles_env[[tid]]
              if (is.character(blk$content)) {
                cstr <- blk$content
              } else {
                cstr <- tryCatch(
                  jsonlite::toJSON(blk$content, auto_unbox = TRUE),
                  error = function(e) ""
                )
              }
              # 审批过的工具：审批卡是最后一条消息，operation="replace" 会
              # 替换审批卡（shinychat 基于位置替换）。改为 chunk=FALSE 追加
              # 新消息，让请求卡和结果卡分开展示，审批卡保留在中间。
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
        # AssistantMessage — 回退（无 StreamEvent 时）
        # ==============================================================
        if (inherits(msg, "AssistantMessage") && !chunk_started) {
          for (blk in msg$content) {
            if (inherits(blk, "TextBlock") &&
                nzchar(blk$text %||% "")) {
              chat_append_message("chat",
                list(role = "assistant", content = blk$text),
                chunk = FALSE, session = session)
            }
            # ThinkingBlock 由 StreamEvent 处理，此处跳过避免重复
            if (inherits(blk, "ToolUseBlock") &&
                is.null(tool_names_env[[blk$id]])) {
              tool_names_env[[blk$id]] <- blk$name
              ajson <- tryCatch(
                jsonlite::toJSON(blk$input %||% list(),
                                 auto_unbox = TRUE),
                error = function(e) "{}"
              )
              atitle <- .make_tool_title(
                blk$name, blk$input %||% list())
              tool_titles_env[[blk$id]] <- atitle
              chat_append_message("chat",
                list(role = "assistant",
                     content = .tool_req_html(
                       blk$id, blk$name, atitle, ajson)),
                chunk = FALSE, session = session)
            }
          }
        }

        # ==============================================================
        # ResultMessage — 对话结束
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

  # ---- ExtendedTask -------------------------------------------------------

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
