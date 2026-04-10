# examples/13_shinychat_streaming.R
# =========================================================================
# ClaudeAgentSDK + shinychat 流式集成示例
# =========================================================================
#
# 依赖安装:
#   install.packages(c("shiny", "bslib", "shinychat", "promises"))
#   devtools::install("path/to/ClaudeAgentSDK")
#
# 运行:
#   shiny::runApp("examples/13_shinychat_streaming.R")
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
        span("ClaudeAgentSDK + shinychat"),
        actionButton("interrupt_btn", "Interrupt", class = "btn-warning btn-sm")
      )
    ),
    chat_ui("chat", fill = TRUE, placeholder = "Ask Claude anything...")
  )
)

# ---- Server --------------------------------------------------------------

server <- function(input, output, session) {

  # --- 1. 初始化 Claude Code 客户端 ---
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns               = 1L,
    permission_mode         = "bypassPermissions",
    include_partial_messages = TRUE   # 启用 StreamEvent（流式文本增量）
  ))
  client$connect()
  onStop(function() client$disconnect())

  # 防止并发请求（单客户端、单子进程）
  is_busy <- reactiveVal(FALSE)

  # --- 打断按钮 ---
  observeEvent(input$interrupt_btn, {
    tryCatch(client$interrupt(), error = function(e) NULL)
  })

  # --- 2. 处理用户输入 ---
  observeEvent(input$chat_user_input, {
    req(!is_busy())
    is_busy(TRUE)

    user_msg <- input$chat_user_input
    sess <- session          # 捕获 session 供 async 回调使用
    chunk_started <- FALSE   # 是否已发送 chunk="start"
    fallback_text <- ""      # 回退用完整文本

    client$send(user_msg)

    p <- client$receive_response_async(on_message = function(msg) {
      # ---- 流式文本增量（StreamEvent）----
      #
      # include_partial_messages=TRUE 时，CLI 为每个 token 发送：
      #   type: "stream_event"
      #   event: { type: "content_block_delta",
      #            delta: { type: "text_delta", text: "..." } }
      #
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

      # ---- 完整 AssistantMessage（回退用）----
      if (inherits(msg, "AssistantMessage")) {
        for (block in msg$content) {
          if (inherits(block, "TextBlock")) {
            fallback_text <<- paste0(fallback_text, block$text)
          }
        }
      }
    })

    # --- 3. Promise 完成 ---
    then(p,
      onFulfilled = function(result) {
        if (chunk_started) {
          # 正常结束流式块
          chat_append_message("chat",
            list(role = "assistant", content = ""),
            chunk = "end", session = sess)
        } else if (nzchar(fallback_text)) {
          # 回退：未收到 StreamEvent，整块显示 AssistantMessage
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

# ---- Run -----------------------------------------------------------------

shinyApp(ui, server)
