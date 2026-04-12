# examples/15_shinychat_tool_approval.R
# =========================================================================
# API 1: 回调式工具审批（on_tool_request + resolve 闭包）
# =========================================================================
#
# 原理：
#   on_tool_request 回调收到 resolve 闭包 →
#   存到 session$userData → 弹出审批框 →
#   用户点按钮 → 从 session$userData 取出 resolve 调用
#
# 特点：
#   - resolve 闭包自包含（内含 request_id 和发送逻辑）
#   - 需要跨 observer 传递闭包引用
#   - 仅在 receive_response_async() 中可用
#
# 打断机制的限制（重要）：
#   receive_response_async() 内部用 later::later() 轮询。在 Shiny 中，
#   later 回调优先于输入事件处理，导致打断按钮的点击事件只有在整个
#   promise resolve 之后才会被 Shiny 处理。
#   → 流式文本期间的打断不可靠（按钮会在流式结束后才生效）
#   → 工具审批弹窗期间打断可靠（此时 later 轮询得到空消息，不阻塞 Shiny）
#
#   如需可靠的流式打断，请使用 example 16（coro::async + poll_messages）。
#
# 运行：
#   shiny::runApp("examples/15_shinychat_tool_approval.R")
#
# 测试提示：
#   输入 "Read the file /dev/null" 或 "List files in /tmp"
#   Claude 会请求使用 Read/Bash 工具 → 弹出审批框
#
# 相关示例：
#   13 — 纯文本流式聊天 + 可靠打断（coro::async 版）
#   14 — 非流式聊天（最简通路）
#   16 — 消息驱动式工具审批（推荐：coro::async + 可靠打断）
#
# =========================================================================

library(shiny)
library(bslib)
library(shinychat)
library(ClaudeAgentSDK)
library(promises)

# ---- UI ------------------------------------------------------------------

ui <- page_fillable(
  theme = bs_theme(bootswatch = "flatly"),
  card(
    card_header(
      div(
        class = "d-flex justify-content-between align-items-center",
        span("API 1: on_tool_request + resolve"),
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

  # permission_prompt_tool_name = "stdio" 让 CLI 发送权限请求
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns                   = 5L,
    permission_prompt_tool_name = "stdio",
    include_partial_messages    = TRUE
  ))
  client$connect()
  onStop(function() client$disconnect())

  is_busy       <- reactiveVal(FALSE)
  chunk_started <- FALSE

  # --- 打断 ---
  observeEvent(input$interrupt_btn, {
    tryCatch(client$interrupt(), error = function(e) NULL)
    if (chunk_started) {
      chat_append_message("chat",
        list(role = "assistant", content = "\n\n_[Interrupted]_"),
        chunk = "end", session = session)
      chunk_started <<- FALSE
    }
    is_busy(FALSE)
    removeModal()
  })

  # --- 审批按钮（存的是 resolve 闭包）---
  observeEvent(input$tool_allow, {
    resolve <- session$userData$pending_resolve
    if (!is.null(resolve)) {
      session$userData$pending_resolve <- NULL
      removeModal()
      resolve(PermissionResultAllow())
    }
  })

  observeEvent(input$tool_deny, {
    resolve <- session$userData$pending_resolve
    if (!is.null(resolve)) {
      session$userData$pending_resolve <- NULL
      removeModal()
      resolve(PermissionResultDeny("Denied by user"))
    }
  })

  # --- 聊天 ---
  observeEvent(input$chat_user_input, {
    req(!is_busy())
    is_busy(TRUE)

    user_msg <- input$chat_user_input
    sess <- session
    chunk_started <<- FALSE
    fallback_text <- ""

    client$send(user_msg)

    p <- client$receive_response_async(
      on_message = function(msg) {
        # 流式文本
        if (inherits(msg, "StreamEvent") && is.list(msg$event)) {
          evt <- msg$event
          if (identical(evt$type, "content_block_delta") &&
              is.list(evt$delta) &&
              identical(evt$delta$type, "text_delta") &&
              !is.null(evt$delta$text)) {
            if (!chunk_started) {
              chunk_started <<- TRUE
              chat_append_message("chat",
                list(role = "assistant", content = ""),
                chunk = "start", session = sess)
            }
            chat_append_message("chat",
              list(role = "assistant", content = evt$delta$text),
              chunk = TRUE, session = sess)
          }
        }
        # 回退用完整文本
        if (inherits(msg, "AssistantMessage")) {
          for (block in msg$content) {
            if (inherits(block, "TextBlock")) {
              fallback_text <<- paste0(fallback_text, block$text)
            }
          }
        }
      },

      # ========== API 1 核心：on_tool_request 回调 ==========
      on_tool_request = function(tool_name, tool_input, ctx, resolve) {
        # 结束当前流式块
        if (chunk_started) {
          chat_append_message("chat",
            list(role = "assistant", content = ""),
            chunk = "end", session = sess)
          chunk_started <<- FALSE
        }

        # 在聊天中显示工具请求信息
        input_json <- jsonlite::toJSON(tool_input, auto_unbox = TRUE, pretty = TRUE)
        chat_append_message("chat",
          list(role = "assistant", content = paste0(
            "\n\n**Tool: `", tool_name, "`**\n\n```json\n",
            input_json, "\n```\n"
          )),
          chunk = FALSE, session = sess)

        # 存 resolve 闭包，弹出审批框
        sess$userData$pending_resolve <- resolve
        showModal(modalDialog(
          title = paste("Allow tool:", tool_name),
          tags$pre(input_json),
          footer = tagList(
            actionButton("tool_allow", "Allow", class = "btn-success"),
            actionButton("tool_deny", "Deny", class = "btn-danger")
          ),
          easyClose = FALSE
        ), session = sess)
      }
    )

    then(p,
      onFulfilled = function(result) {
        if (chunk_started) {
          chat_append_message("chat",
            list(role = "assistant", content = ""),
            chunk = "end", session = sess)
          chunk_started <<- FALSE
        } else if (nzchar(fallback_text)) {
          chat_append_message("chat",
            list(role = "assistant", content = fallback_text),
            chunk = FALSE, session = sess)
        }
        is_busy(FALSE)
      },
      onRejected = function(err) {
        err_text <- paste("Error:", conditionMessage(err))
        if (chunk_started) {
          chat_append_message("chat",
            list(role = "assistant", content = paste0("\n\n", err_text)),
            chunk = "end", session = sess)
          chunk_started <<- FALSE
        } else {
          chat_append_message("chat",
            list(role = "assistant", content = err_text),
            chunk = FALSE, session = sess)
        }
        is_busy(FALSE)
      }
    )
  })
}

shinyApp(ui, server)
