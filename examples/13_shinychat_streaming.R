# examples/13_shinychat_streaming.R — 最小可行版 + 调试日志

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
  do_stream <- coro::async(function(client, interrupt_flag, session) {
    message("[ASYNC] started")

    shinychat::chat_append_message("chat",
      list(role = "assistant", content = ""),
      chunk = "start", session = session)
    message("[ASYNC] chunk=start sent")

    interrupted <- FALSE

    repeat {
      msgs <- tryCatch(client$poll_messages(), error = function(e) {
        message("[ASYNC] poll error: ", e$message)
        list()
      })

      if (length(msgs) == 0L) {
        # 让出控制权 50ms
        await(promises::promise(function(resolve, reject) {
          later::later(function() resolve(TRUE), 0.05)
        }))
        next
      }

      message("[ASYNC] got ", length(msgs), " msgs")

      for (msg in msgs) {
        # 让出控制权（每个 msg 之间）
        await(promises::promise_resolve(TRUE))

        # 中断检查
        if (shiny::isolate(interrupt_flag())) {
          message("[ASYNC] interrupted!")
          interrupted <- TRUE
          break
        }

        # StreamEvent 文本
        if (inherits(msg, "StreamEvent") && is.list(msg$event)) {
          evt <- msg$event
          if (identical(evt$type, "content_block_delta") &&
              is.list(evt$delta) &&
              identical(evt$delta$type, "text_delta") &&
              !is.null(evt$delta$text)) {
            shinychat::chat_append_message("chat",
              list(role = "assistant", content = evt$delta$text),
              chunk = TRUE, session = session)
          }
        }

        # 完成
        if (inherits(msg, "ResultMessage")) {
          message("[ASYNC] ResultMessage, done")
          shinychat::chat_append_message("chat",
            list(role = "assistant", content = ""),
            chunk = "end", session = session)
          return("done")
        }
      }

      if (interrupted) break
    }

    if (interrupted) {
      shinychat::chat_append_message("chat",
        list(role = "assistant", content = "\n\n_[Interrupted]_"),
        chunk = TRUE, session = session)
    }
    shinychat::chat_append_message("chat",
      list(role = "assistant", content = ""),
      chunk = "end", session = session)
    message("[ASYNC] finished, interrupted=", interrupted)
    "done"
  })

  # --- ExtendedTask ---
  stream_task <- ExtendedTask$new(function(user_input) {
    message("[TASK] invoke, sending: ", substr(user_input, 1, 30))
    client$send(user_input)
    message("[TASK] send done, starting async")
    do_stream(client, interrupt_flag, session)
  })

  observeEvent(input$chat_user_input, {
    message("[INPUT] user input received")
    interrupt_flag(FALSE)
    stream_task$invoke(input$chat_user_input)
  })

  observeEvent(input$esc, {
    message("[ESC] pressed, task status=", stream_task$status())
    if (stream_task$status() == "running") {
      interrupt_flag(TRUE)
    }
  })
}

shinyApp(ui, server)
