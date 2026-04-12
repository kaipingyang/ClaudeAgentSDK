# examples/15_shinychat_tool_approval_msgdriven.R
# =========================================================================
# 消息驱动式工具审批（PermissionRequestMessage + approve_tool/deny_tool）
# =========================================================================
#
# 原理：
#   不设 can_use_tool →
#   CLI 的 can_use_tool 请求自动变成 PermissionRequestMessage 进入消息流 →
#   Shiny 弹出审批框 → 用户点按钮 →
#   调 client$approve_tool(request_id) 或 client$deny_tool(request_id)
#
# 打断机制：
#   使用 coro::async + await() 模式，每次 await() 让出 R 事件循环，
#   使 Shiny 能及时处理 ESC 键 / Interrupt 按钮，实现真正的流式打断。
#
#   打断后缓冲区处理（关键）：
#   打断时 CLI 会发出最后一条 ResultMessage。必须等到这条 ResultMessage
#   被消费（drain 模式）才能 return，否则下次发消息时新的 do_stream 会
#   立即拿到这条旧 ResultMessage 并提前退出，导致前端只显示三个点。
#
# 特点：
#   - coro::async + poll_messages() + ExtendedTask：流式 + 可打断
#   - 所有消息走同一个消息循环（含 PermissionRequestMessage）
#   - 用 request_id 字符串做 key
#   - approve_tool/deny_tool 是 client 上的独立方法
#
# 运行：
#   shiny::runApp("examples/15_shinychat_tool_approval_msgdriven.R")
#
# 测试提示：
#   输入 "Read the file /dev/null" 或 "List files in /tmp"
#   Claude 会请求使用 Read/Bash 工具 → 弹出审批框
#   Esc 键或 Interrupt 按钮可打断流式输出
#
# 相关示例：
#   13 — 纯文本流式聊天 + 打断（coro::async 基础版）
#   14 — 非流式聊天（最简通路）
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
        span("消息驱动式工具审批 + 流式打断"),
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

  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns                   = 5L,
    permission_prompt_tool_name = "stdio",
    include_partial_messages    = TRUE
  ))
  client$connect()
  onStop(function() client$disconnect())

  interrupt_flag <- reactiveVal(FALSE)
  pending_id     <- reactiveVal(NULL)

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

  # --- coro::async 流式函数 ---
  #
  # 打断处理流程：
  #   1. 每次循环顶部检测 interrupt_flag
  #   2. 首次检测到时：关闭弹窗（若有）→ deny_tool（若有挂起审批）→
  #      client$interrupt() → 显示 "[Interrupted]"
  #   3. 进入 drain 模式：跳过所有消息，等待 ResultMessage
  #   4. 收到 ResultMessage → break，缓冲区清空，return "done"
  #
  do_stream <- coro::async(function(client, interrupt_flag, pending_id, session) {
    chunk_started <- FALSE
    interrupted   <- FALSE

    repeat {
      # ---- 每次循环顶部检测打断 ----
      if (!interrupted && shiny::isolate(interrupt_flag())) {
        interrupted <- TRUE
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
        await(promises::promise_resolve(TRUE))

        # ---- Drain 模式：等待 ResultMessage 清空缓冲区 ----
        if (interrupted) {
          if (inherits(msg, "ResultMessage")) { drain_done <- TRUE; break }
          next
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

        # ---- 完整文本回退 ----
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

      if (drain_done) break
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
