# examples/14_shinychat_simple.R
# =========================================================================
# Non-streaming chat (display full reply at once, no tool calls)
# =========================================================================
#
# Features:
#   - Wait for the complete AssistantMessage then display it all at once
#   - No include_partial_messages (no StreamEvent tokens)
#   - max_turns = 1, Claude replies with text only, no tool calls
#
# Use case:
#   Simplest possible ClaudeAgentSDK + shinychat integration.
#   Good as a baseline when debugging streaming issues.
#
# Not included:
#   - Streaming display (see example 13)
#   - Tool calls / approval (see example 15)
#   - Interrupt button
#
# Related examples:
#   13 — streaming version (token-by-token display)
#   15 — message-driven tool approval
#
# Run:
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
