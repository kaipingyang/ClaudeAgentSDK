# examples/16_shinychat_tool_approval_inline.R
# =========================================================================
# 内联审批（无弹窗）— 审批 UI 嵌入在 chat_ui 下方
# =========================================================================
#
# 与 example 15 的区别：
#   不弹窗 → 工具请求直接追加为 assistant 消息，
#   chat 下方出现固定审批栏（Allow / Deny 按钮），
#   点击后追加一条确认消息，体验类似 claude code 命令行审批。
#
# 打断 + drain 机制与 example 15 完全相同（参见该文件注释）。
#
# 运行：
#   shiny::runApp("examples/16_shinychat_tool_approval_inline.R")
#
# 测试提示：
#   输入 "Run `echo hello world`" → 审批栏在 chat 下方展开
#   点 Allow → 工具执行，确认消息追加到 chat
#   点 Deny  → 工具拒绝，拒绝消息追加到 chat
#   Esc 键 / Interrupt 按钮 → 打断，drain 清空缓冲区
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
        span("内联工具审批"),
        actionButton("interrupt_btn", "Interrupt", class = "btn-warning btn-sm")
      )
    ),
    # chat 区域占满剩余空间
    chat_ui("chat", fill = TRUE,
            placeholder = "Try: 'Run `echo hello world`'"),
    # 审批栏：有待审批时渲染，否则为空（不占空间）
    uiOutput("approval_ui")
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
  pending_id     <- reactiveVal(NULL)   # request_id 字符串，NULL 表示无待审批
  pending_name   <- reactiveVal(NULL)   # 工具名，用于审批栏标题

  # ---- 审批栏 UI ----
  #
  # 有待审批时渲染一个固定在底部的卡片式审批条；否则返回 NULL（隐藏）。
  output$approval_ui <- renderUI({
    rid  <- pending_id()
    name <- pending_name()
    if (is.null(rid)) return(NULL)

    div(
      style = paste(
        "border-top: 2px solid #f0ad4e;",
        "background: #fff8f0;",
        "padding: 10px 16px;",
        "display: flex;",
        "align-items: center;",
        "gap: 12px;"
      ),
      tags$span(
        style = "font-weight: 600; flex: 1; font-size: 0.9em;",
        tags$span(style = "color: #856404;", "\u26a0\ufe0f"),
        " Allow tool: ",
        tags$code(name %||% "unknown")
      ),
      actionButton("tool_allow", "Allow \u2714",
                   class = "btn-success btn-sm"),
      actionButton("tool_deny",  "Deny \u2716",
                   class = "btn-danger btn-sm")
    )
  })

  # ---- 审批按钮处理 ----

  observeEvent(input$tool_allow, {
    rid  <- pending_id()
    name <- pending_name()
    if (!is.null(rid)) {
      pending_id(NULL)
      pending_name(NULL)
      # 追加确认消息到 chat
      chat_append_message("chat",
        list(role = "assistant",
             content = paste0("\u2705 **Allowed**: `", name %||% rid, "`")),
        chunk = FALSE, session = session)
      client$approve_tool(rid)
    }
  })

  observeEvent(input$tool_deny, {
    rid  <- pending_id()
    name <- pending_name()
    if (!is.null(rid)) {
      pending_id(NULL)
      pending_name(NULL)
      chat_append_message("chat",
        list(role = "assistant",
             content = paste0("\u274c **Denied**: `", name %||% rid, "`")),
        chunk = FALSE, session = session)
      client$deny_tool(rid, "Denied by user")
    }
  })

  # ---- coro::async 流式函数 ----
  #
  # 与 example 15 结构相同。区别：
  #   - 无 showModal / removeModal
  #   - PermissionRequestMessage → pending_id / pending_name（触发 approval_ui 渲染）
  #   - 打断时：清除 pending_id（隐藏审批栏）→ deny 挂起工具 → interrupt
  #
  do_stream <- coro::async(function(client, interrupt_flag,
                                    pending_id, pending_name, session) {
    chunk_started <- FALSE
    interrupted   <- FALSE

    repeat {
      # ---- 每次循环顶部检测打断 ----
      if (!interrupted && shiny::isolate(interrupt_flag())) {
        interrupted <- TRUE
        rid  <- shiny::isolate(pending_id())
        name <- shiny::isolate(pending_name())
        if (!is.null(rid)) {
          pending_id(NULL)
          pending_name(NULL)
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

        # ---- Drain 模式 ----
        if (interrupted) {
          if (inherits(msg, "ResultMessage")) { drain_done <- TRUE; break }
          next
        }

        # ---- 工具审批请求 → 内联审批栏 ----
        if (inherits(msg, "PermissionRequestMessage")) {
          # 若还在流式输出中，先结束当前 chunk
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
            chunk_started <- FALSE
          }

          input_json <- jsonlite::toJSON(msg$tool_input,
                                         auto_unbox = TRUE, pretty = TRUE)

          # 把工具名 + 参数追加为 assistant 消息（类似终端中打印审批详情）
          chat_append_message("chat",
            list(role = "assistant", content = paste0(
              "**Tool request: `", msg$tool_name, "`**\n\n```json\n",
              input_json, "\n```"
            )),
            chunk = FALSE, session = session)

          # 触发审批栏
          pending_id(msg$request_id)
          pending_name(msg$tool_name)
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

        # ---- 完整文本回退（无 StreamEvent 时）----
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

  # ---- ExtendedTask ----
  stream_task <- ExtendedTask$new(function(user_input) {
    client$send(user_input)
    do_stream(client, interrupt_flag, pending_id, pending_name, session)
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
