# examples/15_shinychat_tool_approval.R
# =========================================================================
# ClaudeAgentSDK + shinychat: 流式文本 + 工具审批弹窗
# =========================================================================
#
# 演示内容：
#   1. 流式文本（StreamEvent 增量）
#   2. Claude 请求使用工具时弹出审批对话框
#   3. 用户点击 Allow/Deny 后 Claude 继续/停止
#   4. 打断按钮（interrupt）
#
# 依赖:
#   install.packages(c("shiny", "bslib", "shinychat", "promises"))
#
# 运行:
#   shiny::runApp("examples/15_shinychat_tool_approval.R")
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
        span("Claude + Tool Approval"),
        actionButton("interrupt_btn", "Interrupt",
                     class = "btn-warning btn-sm")
      )
    ),
    chat_ui("chat", fill = TRUE,
            placeholder = "Try: 'Read the file /dev/null' or 'List files in /tmp'")
  )
)

# ---- Server --------------------------------------------------------------

server <- function(input, output, session) {

  # --- 初始化 ---
  # permission_prompt_tool_name = "stdio" 让 CLI 通过控制协议发送权限请求
  # （而不是自己弹 CLI 提示符）
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns                   = 5L,
    permission_prompt_tool_name = "stdio",
    include_partial_messages    = TRUE
  ))
  client$connect()
  onStop(function() client$disconnect())

  is_busy <- reactiveVal(FALSE)

  # --- 打断 ---
  observeEvent(input$interrupt_btn, {
    tryCatch(client$interrupt(), error = function(e) NULL)
  })

  # --- 审批按钮 ---
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
    chunk_started <- FALSE
    fallback_text <- ""

    client$send(user_msg)

    p <- client$receive_response_async(
      on_message = function(msg) {
        # ---- 流式文本增量 ----
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

      on_tool_request = function(tool_name, tool_input, ctx, resolve) {
        # 结束当前流式块（如有）
        if (chunk_started) {
          chat_append_message("chat",
            list(role = "assistant", content = ""),
            chunk = "end", session = sess)
          chunk_started <<- FALSE
        }

        # 在聊天中显示工具请求
        input_json <- jsonlite::toJSON(tool_input, auto_unbox = TRUE, pretty = TRUE)
        chat_append_message("chat",
          list(role = "assistant", content = paste0(
            "\n\n**Tool: `", tool_name, "`**\n\n```json\n",
            input_json, "\n```\n"
          )),
          chunk = FALSE, session = sess)

        # 存储 resolve，弹出审批框
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

    # --- Promise 完成 ---
    then(p,
      onFulfilled = function(result) {
        if (chunk_started) {
          chat_append_message("chat",
            list(role = "assistant", content = ""),
            chunk = "end", session = sess)
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
