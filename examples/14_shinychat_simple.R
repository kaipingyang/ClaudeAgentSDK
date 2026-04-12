# examples/14_shinychat_simple.R
# =========================================================================
# 非流式聊天（一次性显示完整回复，无工具调用）
# =========================================================================
#
# 功能：
#   - 等待完整 AssistantMessage 后一次性显示（不逐 token 流式）
#   - 不使用 include_partial_messages（无 StreamEvent）
#   - max_turns = 1，Claude 只回复文本，不调用任何工具
#
# 适用场景：
#   验证 ClaudeAgentSDK + shinychat 的最简单通路
#   排查流式问题时的对照组
#
# 不包含：
#   - 流式显示（见 example 13）
#   - 工具调用 / 审批（见 example 15/16）
#   - 打断按钮
#
# 相关示例：
#   13 — 流式版本（逐 token 显示）
#   15 — 回调式工具审批（on_tool_request + resolve）
#   16 — 消息驱动式工具审批（PermissionRequestMessage + approve_tool）
#
# 运行：
#   shiny::runApp("examples/14_shinychat_simple.R")
#
# =========================================================================

library(shiny)
library(bslib)
library(shinychat)
library(ClaudeAgentSDK)
library(promises)

ui <- page_fillable(
  card(
    card_header("ClaudeAgentSDK + shinychat (simple)"),
    chat_ui("chat", fill = TRUE, placeholder = "Ask Claude anything...")
  )
)

server <- function(input, output, session) {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions"
  ))
  client$connect()
  onStop(function() client$disconnect())

  is_busy <- reactiveVal(FALSE)

  observeEvent(input$chat_user_input, {
    req(!is_busy())
    is_busy(TRUE)

    user_msg <- input$chat_user_input
    sess <- session
    response_text <- ""

    client$send(user_msg)

    p <- client$receive_response_async(on_message = function(msg) {
      if (inherits(msg, "AssistantMessage")) {
        for (block in msg$content) {
          if (inherits(block, "TextBlock")) {
            response_text <<- paste0(response_text, block$text)
          }
        }
      }
    })

    then(p,
      onFulfilled = function(result) {
        if (nzchar(response_text)) {
          chat_append_message("chat",
            list(role = "assistant", content = response_text),
            chunk = FALSE, session = sess)
        }
        is_busy(FALSE)
      },
      onRejected = function(err) {
        chat_append_message("chat",
          list(role = "assistant", content = paste("Error:", conditionMessage(err))),
          chunk = FALSE, session = sess)
        is_busy(FALSE)
      }
    )
  })
}

shinyApp(ui, server)
