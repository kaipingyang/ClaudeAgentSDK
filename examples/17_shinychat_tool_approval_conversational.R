# examples/17_shinychat_tool_approval_conversational.R
# =========================================================================
# 对话式工具审批 — 完全在 chat_ui 内部通过文字审批
# =========================================================================
#
# 体验：
#   1. Claude 请求某个工具 → chat 中出现工具详情 + 提示信息
#   2. 用户在对话框里输入 "allow" 或 "deny"（支持 y/n/yes/no）
#   3. SDK 根据用户回复调用 approve_tool / deny_tool
#   4. CLI 恢复执行，Claude 继续作答
#
#   类似 claude code 命令行审批流程，但完全在 chat_ui 里完成，无弹窗无按钮。
#
# 实现要点：
#   - pending_id 不为 NULL 时，下一条用户输入被拦截为审批回复，
#     不触发新的 do_stream（只有 pending_id == NULL 时才发消息给 Claude）
#   - do_stream 循环在等待审批时持续 poll，每 50ms 让出事件循环，
#     使 observeEvent(input$chat_user_input) 能在 await 间隙触发
#   - 打断处理与 example 15 / 16 完全相同（drain 模式清空缓冲区）
#
# 运行：
#   shiny::runApp("examples/17_shinychat_tool_approval_conversational.R")
#
# 测试提示：
#   输入 "Run `echo hello world`" → Claude 请求 Bash 工具 → chat 出现审批提示
#   输入 "allow" → 工具执行
#   输入 "deny"  → 工具拒绝
#   输入其他内容  → chat 中提示"请输入 allow 或 deny"
#   Esc 键 / Interrupt 按钮 → 打断
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
        span("对话式工具审批"),
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
  ))
  client$connect()
  onStop(function() client$disconnect())

  interrupt_flag <- reactiveVal(FALSE)
  pending_id     <- reactiveVal(NULL)   # 等待审批的 request_id，NULL = 无待审批
  pending_name   <- reactiveVal(NULL)   # 工具名

  # ---- 用户输入处理 ----
  #
  # 两种状态：
  #   A) pending_id == NULL → 正常对话，发给 Claude
  #   B) pending_id != NULL → 拦截为审批回复
  #
  observeEvent(input$chat_user_input, {

    # ---- 状态 B：审批回复 ----
    rid <- pending_id()
    if (!is.null(rid)) {
      name  <- pending_name()
      reply <- tolower(trimws(input$chat_user_input))

      if (reply %in% c("allow", "y", "yes")) {
        pending_id(NULL)
        pending_name(NULL)
        chat_append_message("chat",
          list(role = "assistant",
               content = paste0("\u2705 **Allowed**: `", name %||% rid, "`")),
          chunk = FALSE, session = session)
        client$approve_tool(rid)

      } else if (reply %in% c("deny", "n", "no")) {
        pending_id(NULL)
        pending_name(NULL)
        chat_append_message("chat",
          list(role = "assistant",
               content = paste0("\u274c **Denied**: `", name %||% rid, "`")),
          chunk = FALSE, session = session)
        client$deny_tool(rid, "Denied by user")

      } else {
        # 输入无效，提示重试（不消耗 pending_id）
        chat_append_message("chat",
          list(role = "assistant",
               content = paste0(
                 "\u2753 请输入 **allow**\uff08\u5141\u8bb8\uff09",
                 " \u6216 **deny**\uff08\u62d2\u7edd\uff09\u3002"
               )),
          chunk = FALSE, session = session)
      }
      return()
    }

    # ---- 状态 A：正常对话 ----
    if (stream_task$status() == "running") return()
    interrupt_flag(FALSE)
    stream_task$invoke(input$chat_user_input)
  })

  # ---- coro::async 流式函数 ----
  do_stream <- coro::async(function(client, interrupt_flag,
                                    pending_id, pending_name, session) {
    chunk_started <- FALSE
    interrupted   <- FALSE

    repeat {
      # ---- 循环顶部检测打断 ----
      if (!interrupted && shiny::isolate(interrupt_flag())) {
        interrupted <- TRUE
        rid <- shiny::isolate(pending_id())
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

        # ---- 工具审批请求 → 对话式提示 ----
        if (inherits(msg, "PermissionRequestMessage")) {
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
            chunk_started <- FALSE
          }

          input_json <- jsonlite::toJSON(msg$tool_input,
                                         auto_unbox = TRUE, pretty = TRUE)

          # 展示工具详情 + 对话式提示
          chat_append_message("chat",
            list(role = "assistant", content = paste0(
              "\u26a0\ufe0f **Tool request: `", msg$tool_name, "`**\n\n",
              "```json\n", input_json, "\n```\n\n",
              "\u2328\ufe0f \u8bf7\u8f93\u5165 **allow** \u6216 **deny** \u6279\u51c6\u6b64\u64cd\u4f5c\u3002"
            )),
            chunk = FALSE, session = session)

          # 标记为等待审批（do_stream 继续 poll，observeEvent 处理回复）
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

  # ---- ExtendedTask ----
  stream_task <- ExtendedTask$new(function(user_input) {
    client$send(user_input)
    do_stream(client, interrupt_flag, pending_id, pending_name, session)
  })

  observeEvent(input$esc, {
    if (stream_task$status() == "running") interrupt_flag(TRUE)
  })

  observeEvent(input$interrupt_btn, {
    if (stream_task$status() == "running") interrupt_flag(TRUE)
  })
}

shinyApp(ui, server)
