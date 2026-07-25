# Tests for in-process SDK MCP servers:
#   sdk_mcp_tool() / create_sdk_mcp_server() + JSON-RPC dispatch
#   + transport `mcp_message` control-request routing.
#
# Pure unit tests — no claude binary required. The dispatch router is a pure
# function; the transport routing is tested by calling the private
# handle_sdk_mcp_request() directly (R6 methods are locked, so we assert on its
# return value rather than stubbing self$send).

# ---------------------------------------------------------------------------
# sdk_mcp_tool()
# ---------------------------------------------------------------------------
test_that("sdk_mcp_tool builds an SdkMcpTool with the expected fields", {
  h <- function(args) list(content = list(list(type = "text", text = "ok")))
  tl <- sdk_mcp_tool(
    name = "greet", description = "Greet a user",
    input_schema = list(name = "string"), handler = h
  )
  expect_s3_class(tl, "SdkMcpTool")
  expect_equal(tl$name, "greet")
  expect_equal(tl$description, "Greet a user")
  expect_true(is.function(tl$handler))
  expect_equal(tl$input_schema, list(name = "string"))
})

test_that("sdk_mcp_tool validates its arguments", {
  expect_error(sdk_mcp_tool(name = c("a", "b"), description = "d",
                            input_schema = list(), handler = function(a) a))
  expect_error(sdk_mcp_tool(name = "n", description = "d",
                            input_schema = list(), handler = "not a function"))
})

# ---------------------------------------------------------------------------
# create_sdk_mcp_server()
# ---------------------------------------------------------------------------
make_calc <- function() {
  add <- sdk_mcp_tool(
    "add", "Add two numbers",
    input_schema = list(a = "number", b = "number"),
    handler = function(args) {
      list(content = list(list(type = "text",
                               text = paste0("Sum: ", args$a + args$b))))
    }
  )
  boom <- sdk_mcp_tool(
    "boom", "Always errors", input_schema = list(),
    handler = function(args) stop("kaboom")
  )
  create_sdk_mcp_server("calc", version = "2.0.0", tools = list(add, boom))
}

test_that("create_sdk_mcp_server returns a type='sdk' config with a tool registry", {
  srv <- make_calc()
  expect_equal(srv$type, "sdk")
  expect_equal(srv$name, "calc")
  expect_equal(srv$version, "2.0.0")
  expect_true(is.list(srv$instance))
  # tools indexed by name, handlers preserved
  expect_true(all(c("add", "boom") %in% names(srv$instance$tools)))
  expect_true(is.function(srv$instance$tools$add$handler))
})

test_that("build_command strips the SDK instance before sending to the CLI", {
  opts <- ClaudeAgentOptions(mcp_servers = list(calc = make_calc()))
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  args <- t$.__enclos_env__$private$build_command()
  idx <- which(args == "--mcp-config")
  expect_length(idx, 1L)
  cfg_json <- args[idx + 1L]
  # instance / handler must NOT leak into the CLI config JSON
  expect_false(grepl("instance", cfg_json))
  expect_false(grepl("handler", cfg_json))
  expect_true(grepl("\"type\":\"sdk\"", cfg_json))
  expect_true(grepl("calc", cfg_json))
})

# ---------------------------------------------------------------------------
# .sdk_mcp_build_schema()
# ---------------------------------------------------------------------------
test_that("schema shorthand becomes an object schema with required props", {
  tl <- sdk_mcp_tool("t", "d", input_schema = list(a = "number", b = "string"),
                     handler = function(args) list(content = list()))
  sch <- ClaudeAgentSDK:::.sdk_mcp_build_schema(tl)
  expect_equal(sch$type, "object")
  expect_equal(sch$properties$a$type, "number")
  expect_equal(sch$properties$b$type, "string")
  expect_setequal(sch$required, c("a", "b"))
})

test_that("a full JSON schema is passed through untouched", {
  full <- list(type = "object",
               properties = list(x = list(type = "integer")),
               required = list("x"))
  tl <- sdk_mcp_tool("t", "d", input_schema = full,
                     handler = function(args) list(content = list()))
  sch <- ClaudeAgentSDK:::.sdk_mcp_build_schema(tl)
  expect_equal(sch, full)
})

# ---------------------------------------------------------------------------
# .sdk_mcp_dispatch()  — the JSON-RPC router (pure)
# ---------------------------------------------------------------------------
test_that("dispatch: initialize returns protocol + serverInfo", {
  srv <- make_calc()
  resp <- ClaudeAgentSDK:::.sdk_mcp_dispatch(
    srv, list(jsonrpc = "2.0", id = 1L, method = "initialize"))
  expect_equal(resp$result$protocolVersion, "2024-11-05")
  expect_true(!is.null(resp$result$capabilities$tools))
  expect_equal(resp$result$serverInfo$name, "calc")
  expect_equal(resp$result$serverInfo$version, "2.0.0")
  expect_equal(resp$id, 1L)
})

test_that("dispatch: tools/list returns the tools with inputSchema", {
  srv <- make_calc()
  resp <- ClaudeAgentSDK:::.sdk_mcp_dispatch(
    srv, list(jsonrpc = "2.0", id = 2L, method = "tools/list"))
  nms <- vapply(resp$result$tools, function(x) x$name, character(1))
  expect_setequal(nms, c("add", "boom"))
  add <- Filter(function(x) x$name == "add", resp$result$tools)[[1]]
  expect_equal(add$description, "Add two numbers")
  expect_equal(add$inputSchema$type, "object")
  expect_true("a" %in% names(add$inputSchema$properties))
})

test_that("dispatch: tools/call runs the handler and returns content", {
  srv <- make_calc()
  resp <- ClaudeAgentSDK:::.sdk_mcp_dispatch(srv, list(
    jsonrpc = "2.0", id = 3L, method = "tools/call",
    params = list(name = "add", arguments = list(a = 2, b = 3))))
  expect_null(resp$error)
  expect_equal(resp$result$content[[1]]$type, "text")
  expect_equal(resp$result$content[[1]]$text, "Sum: 5")
  expect_null(resp$result$isError)
})

test_that("dispatch: tools/call handler error becomes a JSON-RPC error", {
  srv <- make_calc()
  resp <- ClaudeAgentSDK:::.sdk_mcp_dispatch(srv, list(
    jsonrpc = "2.0", id = 4L, method = "tools/call",
    params = list(name = "boom", arguments = list())))
  expect_equal(resp$error$code, -32603)
  expect_true(grepl("kaboom", resp$error$message))
})

test_that("dispatch: unknown tool -> error", {
  srv <- make_calc()
  resp <- ClaudeAgentSDK:::.sdk_mcp_dispatch(srv, list(
    jsonrpc = "2.0", id = 5L, method = "tools/call",
    params = list(name = "nope", arguments = list())))
  expect_false(is.null(resp$error))
})

test_that("dispatch: notifications/initialized is acked without an error", {
  srv <- make_calc()
  resp <- ClaudeAgentSDK:::.sdk_mcp_dispatch(
    srv, list(jsonrpc = "2.0", method = "notifications/initialized"))
  expect_equal(resp$jsonrpc, "2.0")
  expect_null(resp$error)
})

test_that("dispatch: unknown method -> -32601", {
  srv <- make_calc()
  resp <- ClaudeAgentSDK:::.sdk_mcp_dispatch(
    srv, list(jsonrpc = "2.0", id = 6L, method = "resources/list"))
  expect_equal(resp$error$code, -32601)
})

# ---------------------------------------------------------------------------
# transport routing: handle_sdk_mcp_request()
# ---------------------------------------------------------------------------
test_that("handle_sdk_mcp_request routes to the named server and wraps mcp_response", {
  opts <- ClaudeAgentOptions(mcp_servers = list(calc = make_calc()))
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  out <- t$.__enclos_env__$private$handle_sdk_mcp_request(list(
    server_name = "calc",
    message = list(jsonrpc = "2.0", id = 7L, method = "tools/call",
                   params = list(name = "add", arguments = list(a = 10, b = 5)))))
  expect_true(!is.null(out$mcp_response))
  expect_equal(out$mcp_response$result$content[[1]]$text, "Sum: 15")
})

test_that("handle_sdk_mcp_request errors for an unknown server", {
  opts <- ClaudeAgentOptions(mcp_servers = list(calc = make_calc()))
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  out <- t$.__enclos_env__$private$handle_sdk_mcp_request(list(
    server_name = "ghost",
    message = list(jsonrpc = "2.0", id = 8L, method = "tools/list")))
  expect_false(is.null(out$mcp_response$error))
})

test_that("initialize handshake advertises mcp_message support", {
  opts <- ClaudeAgentOptions()
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  resp <- t$.__enclos_env__$private$handle_initialize_request_inline(list())
  expect_true("mcp_message" %in% resp$supportedControlMessages)
})

# ---------------------------------------------------------------------------
# stdio transport (.mcp_stdio_reply / mcp_serve_stdio)
# ---------------------------------------------------------------------------
test_that(".mcp_stdio_reply answers requests and stays silent for notifications", {
  srv <- make_calc()
  # request with id -> JSON response
  r_init <- ClaudeAgentSDK:::.mcp_stdio_reply(srv, '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
  expect_type(r_init, "character")
  expect_true(grepl("2024-11-05", r_init))
  r_call <- ClaudeAgentSDK:::.mcp_stdio_reply(srv,
    '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"add","arguments":{"a":2,"b":3}}}')
  expect_true(grepl("Sum: 5", r_call))
  # notification (no id) -> no response
  expect_null(ClaudeAgentSDK:::.mcp_stdio_reply(srv, '{"jsonrpc":"2.0","method":"notifications/initialized"}'))
  # blank / garbage -> no response
  expect_null(ClaudeAgentSDK:::.mcp_stdio_reply(srv, "   "))
  expect_null(ClaudeAgentSDK:::.mcp_stdio_reply(srv, "not json"))
})

test_that("mcp_serve_stdio reads requests from input and writes JSON replies", {
  srv <- make_calc()
  reqs <- paste(
    '{"jsonrpc":"2.0","id":1,"method":"initialize"}',
    '{"jsonrpc":"2.0","method":"notifications/initialized"}',
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}',
    '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add","arguments":{"a":10,"b":5}}}',
    sep = "\n"
  )
  input  <- textConnection(reqs)
  outfile <- tempfile()
  output <- file(outfile, "w")
  mcp_serve_stdio(srv, input = input, output = output)
  close(output); close(input)
  lines <- readLines(outfile)
  # 3 requests with id -> 3 responses; the notification produced none
  expect_length(lines, 3L)
  expect_true(any(grepl("2024-11-05", lines)))
  expect_true(any(grepl("\"add\"", lines)))
  expect_true(any(grepl("Sum: 15", lines)))
})
