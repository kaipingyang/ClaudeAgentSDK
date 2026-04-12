# examples/13_shinychat_streaming.R — 流式聊天 + 可靠打断

library(shiny)
library(bslib)
library(shinychat)
library(ClaudeAgentSDK)
library(promises)
library(coro)

ui <- page_fillable(
  chat_ui("chat", fill = TRUE, placeholder = "Test..."),
  tags$script(HTML("
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        Shiny.setInputValue('esc', Math.random(), {priority: 'event'});
      }
    });
  "))
)

server <- function(input, output, session) {

  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns = 1L,
    permission_mode = "bypassPermissions",
    include_partial_messages = TRUE
  ))
  client$connect()
  onStop(function() client$disconnect())

  interrupt_flag <- reactiveVal(FALSE)

  # --- coro::async 协程 ---
  #
  # 打断处理：
  #   1. 每次循环顶部检测 interrupt_flag
  #   2. 首次检测到时：立即清理 UI + 调 client$interrupt()
  #   3. 之后进入 drain 模式：跳过所有消息直到 ResultMessage
  #   4. 收到 ResultMessage 后 break，缓冲区清空，下次调用可正常使用
  #
  do_stream <- coro::async(function(client, interrupt_flag, session) {
    chunk_started <- FALSE
    interrupted   <- FALSE

    repeat {
      # ---- 每次循环顶部检测打断 ----
      if (!interrupted && shiny::isolate(interrupt_flag())) {
        interrupted <- TRUE
        tryCatch(client$interrupt(), error = function(e) NULL)
        if (chunk_started) {
          shinychat::chat_append_message("chat",
            list(role = "assistant", content = "\n\n_[Interrupted]_"),
            chunk = "end", session = session)
          chunk_started <- FALSE
        } else {
          shinychat::chat_append_message("chat",
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

        # ---- StreamEvent 文本 ----
        if (inherits(msg, "StreamEvent") && is.list(msg$event)) {
          evt <- msg$event
          if (identical(evt$type, "content_block_delta") &&
              is.list(evt$delta) &&
              identical(evt$delta$type, "text_delta") &&
              !is.null(evt$delta$text)) {
            if (!chunk_started) {
              chunk_started <- TRUE
              shinychat::chat_append_message("chat",
                list(role = "assistant", content = ""),
                chunk = "start", session = session)
            }
            shinychat::chat_append_message("chat",
              list(role = "assistant", content = evt$delta$text),
              chunk = TRUE, session = session)
          }
        }

        # ---- 完成 ----
        if (inherits(msg, "ResultMessage")) {
          if (chunk_started) {
            shinychat::chat_append_message("chat",
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
    do_stream(client, interrupt_flag, session)
  })

  observeEvent(input$chat_user_input, {
    if (stream_task$status() == "running") return()
    interrupt_flag(FALSE)
    stream_task$invoke(input$chat_user_input)
  })

  observeEvent(input$esc, {
    if (stream_task$status() == "running") interrupt_flag(TRUE)
  })
}

shinyApp(ui, server)
