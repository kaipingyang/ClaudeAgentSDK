# examples/16_shinychat_tool_approval_msgdriven.R
# =========================================================================
# API 2: 消息驱动式工具审批（PermissionRequestMessage + approve_tool/deny_tool）
# =========================================================================
#
# 原理：
#   不设 on_tool_request 也不设 can_use_tool →
#   CLI 的 can_use_tool 请求自动变成 PermissionRequestMessage 进入消息流 →
#   Shiny 弹出审批框 → 用户点按钮 →
#   调 client$approve_tool(request_id) 或 client$deny_tool(request_id)
#
# 打断机制（关键）：
#   使用 coro::async + await() 模式，每次 await() 让出 R 事件循环，
#   使 Shiny 能及时处理 ESC 键 / Interrupt 按钮，实现真正的流式打断。
#   （receive_response_async 的 later::later 轮询会在 Shiny 输入事件前优先
#    执行，导致打断按钮只有在 promise 结束后才生效，不适合需要打断的场景。）
#
# 特点：
#   - coro::async + poll_messages() + ExtendedTask：流式 + 可打断
#   - 所有消息走同一个消息循环（含 PermissionRequestMessage）
#   - 用 request_id 字符串做 key，不需要存闭包
#   - approve_tool/deny_tool 是 client 上的独立方法
#
# 运行：
#   shiny::runApp("examples/16_shinychat_tool_approval_msgdriven.R")
#
# 测试提示：
#   输入 "Read the file /dev/null" 或 "List files in /tmp"
#   Claude 会请求使用 Read/Bash 工具 → 弹出审批框
#   Esc 键或 Interrupt 按钮可打断流式输出
#
# 相关示例：
#   13 — 纯文本流式聊天 + 打断（coro::async 基础版）
#   14 — 非流式聊天（最简通路）
#   15 — 回调式工具审批（on_tool_request + resolve 闭包，无可靠打断）
#
# =========================================================================

library(shiny)
library(bslib)
library(shinychat)
library(ClaudeAgentSDK)
library(promises)
library(coro)

# ---- UI ------------------------------------------------------------------

ui <- page_fillable(
  theme = bs_theme(bootswatch = "flatly"),
  # ESC 键触发打断（priority:'event' 确保立即触发，不被 later 轮询淹没）
  tags$script(HTML("
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        Shiny.setInputValue('esc', Math.random(), {priority: 'event'});
      }
    });
  ")),
  card(
    card_header(
      div(
        class = "d-flex justify-content-between align-items-center",
        span("API 2: PermissionRequestMessage + approve_tool"),
        actionButton("interrupt_btn", "Interrupt",
                     class = "btn-warning btn-sm")
      )
    ),
    chat_ui("chat", fill = TRUE,
            placeholder = "Try: 'Read the file /dev/null'")
  )
)

# ---- Server --------------------------------------------------------------

server <- function(input, output, session) {

  # 不设 can_use_tool，不传 on_tool_request →
  # can_use_tool 请求自动变成 PermissionRequestMessage
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns                   = 5L,
    permission_prompt_tool_name = "stdio",
    include_partial_messages    = TRUE
  ))
  client$connect()
  onStop(function() client$disconnect())

  interrupt_flag <- reactiveVal(FALSE)
  pending_id     <- reactiveVal(NULL)   # 存 request_id 字符串

  # --- 审批按钮 ---
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

  # --- coro::async 流式函数（含工具审批 + 打断）---
  #
  # 关键机制：
  #   await(promise_resolve(TRUE))  — 每条消息处理后让出事件循环
  #   await(50ms promise)           — 无消息时等待，给 Shiny 处理输入的时机
  #   isolate(interrupt_flag())     — 在非 reactive 上下文中安全读取
  #
  do_stream <- coro::async(function(client, interrupt_flag, pending_id, session) {
    chunk_started <- FALSE
    interrupted   <- FALSE

    repeat {
      msgs <- tryCatch(client$poll_messages(), error = function(e) list())

      if (length(msgs) == 0L) {
        # 让出 50ms，让 Shiny 处理 ESC / 按钮事件
        await(promises::promise(function(resolve, reject) {
          later::later(function() resolve(TRUE), 0.05)
        }))
        next
      }

      for (msg in msgs) {
        # 每条消息间让出控制权（关键：允许 observeEvent 触发）
        await(promises::promise_resolve(TRUE))

        # 检查打断标志
        if (shiny::isolate(interrupt_flag())) {
          interrupted <- TRUE
          break
        }

        # ---- 工具审批请求 ----
        if (inherits(msg, "PermissionRequestMessage")) {
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
            chunk_started <- FALSE
          }

          input_json <- jsonlite::toJSON(msg$tool_input,
                                         auto_unbox = TRUE, pretty = TRUE)
          chat_append_message("chat",
            list(role = "assistant", content = paste0(
              "\n\n**Tool: `", msg$tool_name, "`**\n\n```json\n",
              input_json, "\n```\n"
            )),
            chunk = FALSE, session = session)

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
          next
        }

        # ---- 流式文本增量 ----
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

        # ---- 完整文本回退（无 include_partial_messages 时）----
        if (inherits(msg, "AssistantMessage") && !chunk_started) {
          for (block in msg$content) {
            if (inherits(block, "TextBlock") && nzchar(block$text)) {
              chat_append_message("chat",
                list(role = "assistant", content = block$text),
                chunk = FALSE, session = session)
            }
          }
        }

        # ---- 完成 ----
        if (inherits(msg, "ResultMessage")) {
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
          }
          return("done")
        }
      }

      if (interrupted) break
    }

    # 打断收尾
    if (interrupted) {
      rid <- shiny::isolate(pending_id())
      if (!is.null(rid)) {
        pending_id(NULL)
        removeModal(session = session)
      }
      tryCatch(client$interrupt(), error = function(e) NULL)
      if (chunk_started) {
        chat_append_message("chat",
          list(role = "assistant", content = "\n\n_[Interrupted]_"),
          chunk = "end", session = session)
      } else {
        chat_append_message("chat",
          list(role = "assistant", content = "_[Interrupted]_"),
          chunk = FALSE, session = session)
      }
    }

    "done"
  })

  # --- ExtendedTask ---
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
