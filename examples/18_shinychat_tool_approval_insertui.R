# examples/18_shinychat_tool_approval_insertui.R
# =========================================================================
# insertUI 审批 — 审批卡片作为历史记录插入 chat 消息流
# =========================================================================
#
# 体验：
#   1. Claude 请求工具 → 审批卡片（含 Allow / Deny 按钮）通过 insertUI
#      追加到 chat 消息区，成为对话历史的一部分
#   2. 点击 Allow / Deny → 卡片原地替换为已确认徽章（✅ / ❌）
#      并调用 approve_tool / deny_tool
#   3. 审批记录在 chat 中永久可见（不消失），滚动历史时可回顾
#
# 与其他审批示例的区别：
#   15 — modal 弹窗（覆盖 chat，审批后消失）
#   16 — 底部固定审批栏（chat 外部）
#   17 — 纯文字对话（用户输入 allow/deny）
#   18 — insertUI 卡片（插入历史流，原地替换为已确认状态）← 本示例
#
# 实现要点：
#   - 每个审批请求生成唯一 ID（基于 request_id），对应：
#       wrap_id  — 审批卡片容器（用于 removeUI / replaceUI）
#       allow_id — Allow 按钮输入 ID
#       deny_id  — Deny 按钮输入 ID
#   - observeEvent(input[[allow_id]], ..., once = TRUE) — 一次性 observer，
#     点击后自动注销，防止僵尸 observer 堆积
#   - removeUI 移除按钮卡片 → insertUI 在同位置插入已确认徽章
#   - pending_id 仍用于打断时自动 deny 挂起的工具
#
# 运行：
#   shiny::runApp("examples/18_shinychat_tool_approval_insertui.R")
#
# 测试提示：
#   输入 "Run `echo hello world`" → 审批卡片出现在 chat 历史中
#   点 Allow → 卡片原地变为 "✅ Allowed: Bash"
#   点 Deny  → 卡片原地变为 "❌ Denied: Bash"
#   Esc / Interrupt → 打断，drain 清空缓冲区
#
# =========================================================================

library(shiny)
library(bslib)
library(shinychat)
library(ClaudeAgentSDK)
library(promises)
library(coro)

# ---- 审批卡片 UI 构建函数 ------------------------------------------------

# 生成审批卡片（含 Allow / Deny 按钮）
approval_card <- function(wrap_id, allow_id, deny_id, tool_name, input_json) {
  div(
    id    = wrap_id,
    style = paste(
      "margin: 4px 0;",
      "padding: 12px 14px;",
      "border-left: 3px solid #f0ad4e;",
      "background: #fff8f0;",
      "border-radius: 4px;",
      "font-size: 0.9em;"
    ),
    div(
      style = "font-weight: 600; margin-bottom: 6px;",
      tags$span(style = "color: #856404;", "\u26a0\ufe0f"),
      " Tool request: ",
      tags$code(tool_name)
    ),
    tags$pre(
      style = "margin: 6px 0; font-size: 0.82em; max-height: 120px; overflow-y: auto;",
      input_json
    ),
    div(
      style = "display: flex; gap: 8px; margin-top: 8px;",
      actionButton(allow_id, "\u2714 Allow",
                   class = "btn-success btn-sm",
                   style = "padding: 3px 12px;"),
      actionButton(deny_id, "\u2716 Deny",
                   class = "btn-danger btn-sm",
                   style = "padding: 3px 12px;")
    )
  )
}

# 生成已确认徽章（替换审批卡片）
confirmed_badge <- function(wrap_id, allowed, tool_name) {
  div(
    id    = wrap_id,
    style = paste(
      "margin: 4px 0;",
      "padding: 6px 14px;",
      "border-radius: 4px;",
      "font-size: 0.88em;",
      if (allowed) "background: #d4edda; color: #155724;" else
                   "background: #f8d7da; color: #721c24;"
    ),
    if (allowed) "\u2705 Allowed: " else "\u274c Denied: ",
    tags$code(tool_name)
  )
}

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
        span("insertUI 工具审批（历史记录）"),
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
  pending_id     <- reactiveVal(NULL)
  pending_name   <- reactiveVal(NULL)

  # ---- 工具请求处理：生成卡片 + 注册一次性 observer --------------------

  handle_permission <- function(msg) {
    suffix   <- gsub("[^a-zA-Z0-9]", "_", msg$request_id)
    wrap_id  <- paste0("wrap_",  suffix)
    allow_id <- paste0("allow_", suffix)
    deny_id  <- paste0("deny_",  suffix)

    rid  <- msg$request_id
    name <- msg$tool_name
    input_json <- jsonlite::toJSON(msg$tool_input,
                                   auto_unbox = TRUE, pretty = TRUE)

    # 插入审批卡片到 chat 历史
    insertUI(
      selector  = "#chat",
      where     = "beforeEnd",
      immediate = TRUE,
      session   = session,
      ui        = approval_card(wrap_id, allow_id, deny_id, name, input_json)
    )

    # 记录待审批（供打断时 deny）
    pending_id(rid)
    pending_name(name)

    # ---- Allow（一次性 observer）----
    observeEvent(input[[allow_id]], {
      pending_id(NULL)
      pending_name(NULL)
      removeUI(paste0("#", wrap_id), session = session, immediate = TRUE)
      insertUI(
        selector  = paste0("#", wrap_id),
        where     = "afterEnd",
        immediate = TRUE,
        session   = session,
        ui        = confirmed_badge(wrap_id, TRUE, name)
      )
      client$approve_tool(rid)
    }, once = TRUE, ignoreNULL = TRUE, ignoreInit = TRUE)

    # ---- Deny（一次性 observer）----
    observeEvent(input[[deny_id]], {
      pending_id(NULL)
      pending_name(NULL)
      removeUI(paste0("#", wrap_id), session = session, immediate = TRUE)
      insertUI(
        selector  = paste0("#", wrap_id),
        where     = "afterEnd",
        immediate = TRUE,
        session   = session,
        ui        = confirmed_badge(wrap_id, FALSE, name)
      )
      client$deny_tool(rid, "Denied by user")
    }, once = TRUE, ignoreNULL = TRUE, ignoreInit = TRUE)
  }

  # ---- coro::async 流式函数 --------------------------------------------

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
          if (inherits(msg, "ResultMessage")) {
            drain_done <- TRUE
            break
          }
          next
        }

        # ---- 工具审批请求 → insertUI 卡片 ----
        if (inherits(msg, "PermissionRequestMessage")) {
          if (chunk_started) {
            chat_append_message("chat",
              list(role = "assistant", content = ""),
              chunk = "end", session = session)
            chunk_started <- FALSE
          }
          handle_permission(msg)
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

  # ---- ExtendedTask ----------------------------------------------------

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
