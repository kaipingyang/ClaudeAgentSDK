# Real-machine verification of in-process SDK MCP tools against the live claude CLI.
# Proves the full round-trip: CLI -> control_request(mcp_message, tools/call)
# -> R handler runs in-process -> mcp_response -> Claude uses the result.
readRenviron(".Renviron")
library(ClaudeAgentSDK)

tracer <- new.env(parent = emptyenv())
tracer$calls <- list()

add <- sdk_mcp_tool(
  name = "add",
  description = "Add two numbers and return their sum.",
  input_schema = list(
    a = list(type = "number", description = "first addend"),
    b = list(type = "number", description = "second addend")
  ),
  handler = function(args) {
    tracer$calls[[length(tracer$calls) + 1L]] <- args
    total <- as.numeric(args$a) + as.numeric(args$b)
    list(content = list(list(type = "text", text = paste0("The sum is ", total))))
  }
)

server <- create_sdk_mcp_server("calc", version = "1.0.0", tools = list(add))

opts <- ClaudeAgentOptions(
  mcp_servers     = list(calc = server),
  allowed_tools   = c("mcp__calc__add"),
  permission_mode = "bypassPermissions",
  max_turns       = 5L
)

cat("=== sending prompt ===\n")
result <- claude_run(
  "Use the add tool (mcp__calc__add) to compute 17 + 25, then tell me the number.",
  options = opts
)

text <- ""
for (msg in result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (block in msg$content) {
      if (inherits(block, "TextBlock")) text <- paste(text, block$text)
    }
  }
}

cat("\n=== RESULTS ===\n")
cat("handler invoked:", length(tracer$calls), "time(s)\n")
if (length(tracer$calls)) {
  cat("first call args: a=", tracer$calls[[1]]$a, " b=", tracer$calls[[1]]$b, "\n", sep = "")
}
cat("assistant text:", trimws(text), "\n")

tool_ran   <- length(tracer$calls) >= 1L
args_ok    <- tool_ran && as.numeric(tracer$calls[[1]]$a) == 17 &&
              as.numeric(tracer$calls[[1]]$b) == 25
answer_ok  <- grepl("42", text)

cat("\nVERDICT\n")
cat("  [", if (tool_ran)  "PASS" else "FAIL", "] in-process handler was called via mcp_message\n")
cat("  [", if (args_ok)   "PASS" else "FAIL", "] handler received a=17 b=25\n")
cat("  [", if (answer_ok) "PASS" else "FAIL", "] Claude reported 42 using the tool result\n")
if (tool_ran && answer_ok) cat("\nSDK_MCP_VERIFY_OK\n") else cat("\nSDK_MCP_VERIFY_FAIL\n")
