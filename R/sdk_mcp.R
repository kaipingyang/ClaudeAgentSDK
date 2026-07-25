# In-process SDK MCP servers
# ---------------------------------------------------------------------------
# Mirrors the Python SDK's `tool()` / `create_sdk_mcp_server()` / `SdkMcpTool`.
# Unlike external MCP servers (a separate stdio/http process the CLI connects
# to — see `r_mcp_server()`), an SDK MCP server runs *in-process*: the CLI
# routes each tool call back over the stream-json control protocol
# (`control_request` with `subtype = "mcp_message"`, carrying a JSON-RPC 2.0
# message), and the handler runs inside this R session with direct access to
# its state. No subprocess, no extra dependencies (jsonlite only) — so it never
# pulls in ellmer/httr2/curl and is safe in curl-pinned renv projects.

#' Define an in-process SDK MCP tool
#'
#' Creates a tool that runs *inside* the R SDK process. Pass the result to
#' [create_sdk_mcp_server()] and register the server via
#' `ClaudeAgentOptions(mcp_servers = ...)`. This is the R analogue of the
#' Python SDK's `tool()` decorator; it is named `sdk_mcp_tool()` (rather than
#' `tool()`) to avoid masking `ellmer::tool()`.
#'
#' @param name Character(1). Unique tool identifier Claude uses to call it.
#' @param description Character(1). What the tool does (helps Claude decide).
#' @param input_schema List. Either a full JSON Schema (a list with `type` and
#'   `properties`), or a shorthand mapping parameter names to a type string
#'   (e.g. `list(x = "number", label = "string")`) or to a partial schema
#'   (e.g. `list(x = list(type = "number", description = "..."))`).
#' @param handler Function of one argument (a named list of the call
#'   arguments). It should return a list with a `content` field —
#'   `list(content = list(list(type = "text", text = "...")))` — and may set
#'   `isError = TRUE`. A bare character string is also accepted and wrapped as
#'   text content.
#' @param annotations Optional list of MCP tool annotations.
#' @return An object of class `SdkMcpTool`.
#' @examples
#' greet <- sdk_mcp_tool(
#'   name = "greet", description = "Greet a user",
#'   input_schema = list(name = "string"),
#'   handler = function(args) {
#'     list(content = list(list(type = "text",
#'                              text = paste0("Hello, ", args$name, "!"))))
#'   }
#' )
#' @seealso [create_sdk_mcp_server()]
#' @export
sdk_mcp_tool <- function(name, description, input_schema, handler,
                         annotations = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("`name` must be a non-empty character(1).", call. = FALSE)
  }
  if (!is.character(description) || length(description) != 1L) {
    stop("`description` must be a character(1).", call. = FALSE)
  }
  if (!is.function(handler)) {
    stop("`handler` must be a function of one argument.", call. = FALSE)
  }
  if (is.null(input_schema)) input_schema <- list()
  if (!is.list(input_schema)) {
    stop("`input_schema` must be a list.", call. = FALSE)
  }
  structure(
    list(
      name        = name,
      description = description,
      input_schema = input_schema,
      handler     = handler,
      annotations = annotations
    ),
    class = "SdkMcpTool"
  )
}

#' Create an in-process SDK MCP server
#'
#' Bundles [sdk_mcp_tool()] definitions into a server configuration that runs
#' inside the R SDK process. Pass it inside `ClaudeAgentOptions(mcp_servers =
#' list(<name> = create_sdk_mcp_server(...)))`. The R analogue of the Python
#' SDK's `create_sdk_mcp_server()`.
#'
#' @param name Character(1). Server identifier referenced in `mcp_servers`.
#' @param version Character(1). Informational server version.
#' @param tools List of `SdkMcpTool` objects (from [sdk_mcp_tool()]).
#' @return An object of class `McpSdkServerConfig`: a list with `type = "sdk"`,
#'   `name`, `version`, and an `instance` holding the tool registry. The
#'   transport strips `instance` before forwarding the config to the CLI; the
#'   registry stays in-process to dispatch tool calls.
#' @examples
#' add <- sdk_mcp_tool(
#'   "add", "Add two numbers", list(a = "number", b = "number"),
#'   function(args) list(content = list(list(
#'     type = "text", text = paste0("Sum: ", args$a + args$b))))
#' )
#' server <- create_sdk_mcp_server("calc", version = "1.0.0", tools = list(add))
#' \dontrun{
#' opts <- ClaudeAgentOptions(
#'   mcp_servers   = list(calc = server),
#'   allowed_tools = "mcp__calc__add"
#' )
#' }
#' @seealso [sdk_mcp_tool()]
#' @export
create_sdk_mcp_server <- function(name, version = "1.0.0", tools = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("`name` must be a non-empty character(1).", call. = FALSE)
  }
  tools <- tools %||% list()
  registry <- list()
  for (tl in tools) {
    if (!inherits(tl, "SdkMcpTool")) {
      stop("`tools` must be a list of sdk_mcp_tool() objects.", call. = FALSE)
    }
    registry[[tl$name]] <- tl
  }
  structure(
    list(
      type    = "sdk",
      name    = name,
      version = version,
      instance = list(name = name, version = version, tools = registry)
    ),
    class = "McpSdkServerConfig"
  )
}

# Build a tool's MCP inputSchema (mirrors Python _build_schema).
# @keywords internal
.sdk_mcp_build_schema <- function(tool) {
  schema <- tool$input_schema
  if (is.null(schema)) schema <- list()
  # Full JSON Schema -> pass through untouched.
  if (!is.null(schema[["type"]]) && !is.null(schema[["properties"]])) {
    return(schema)
  }
  props <- list()
  for (nm in names(schema)) {
    spec <- schema[[nm]]
    if (is.character(spec) && length(spec) == 1L) {
      props[[nm]] <- list(type = spec)
    } else if (is.list(spec)) {
      props[[nm]] <- spec
    } else {
      props[[nm]] <- list(type = "string")
    }
  }
  if (!length(props)) {
    # empty object schema; keep `properties` an object ({}) not an array ([])
    return(list(type = "object",
                properties = stats::setNames(list(), character(0))))
  }
  list(
    type       = "object",
    properties = props,
    # a list (not a bare vector) so it serialises as a JSON array even for len 1
    required   = as.list(names(props))
  )
}

# Normalise a handler's return value into an MCP tool-call result.
# @keywords internal
.sdk_mcp_normalize_result <- function(res) {
  if (is.list(res) && !is.null(res[["content"]])) {
    out <- list(content = res[["content"]])
    if (isTRUE(res[["isError"]]) || isTRUE(res[["is_error"]])) {
      out$isError <- TRUE
    }
    return(out)
  }
  if (is.character(res)) {
    return(list(content = list(list(type = "text",
                                    text = paste(res, collapse = "\n")))))
  }
  list(content = list(list(
    type = "text",
    text = paste(utils::capture.output(print(res)), collapse = "\n")
  )))
}

# Route a single JSON-RPC 2.0 message to an SDK MCP server (pure; mirrors
# Python _handle_sdk_mcp_request). Returns the JSON-RPC response list.
# @keywords internal
.sdk_mcp_dispatch <- function(server_config, message) {
  id     <- message[["id"]]
  method <- message[["method"]]
  params <- message[["params"]]
  if (is.null(params)) params <- list()
  tools  <- server_config$instance$tools %||% list()

  ok  <- function(result) list(jsonrpc = "2.0", id = id, result = result)
  err <- function(code, msg) {
    list(jsonrpc = "2.0", id = id, error = list(code = code, message = msg))
  }

  if (identical(method, "initialize")) {
    return(ok(list(
      protocolVersion = "2024-11-05",
      capabilities    = list(tools = stats::setNames(list(), character(0))),
      serverInfo      = list(
        name    = server_config$name,
        version = server_config$version %||% "1.0.0"
      )
    )))
  }

  if (identical(method, "tools/list")) {
    tl <- lapply(tools, function(tool) {
      item <- list(
        name        = tool$name,
        description = tool$description,
        inputSchema = .sdk_mcp_build_schema(tool)
      )
      if (!is.null(tool$annotations)) item$annotations <- tool$annotations
      item
    })
    names(tl) <- NULL
    return(ok(list(tools = tl)))
  }

  if (identical(method, "tools/call")) {
    nm   <- params[["name"]]
    args <- params[["arguments"]]
    if (is.null(args)) args <- list()
    tool <- if (!is.null(nm)) tools[[nm]] else NULL
    if (is.null(tool)) {
      return(err(-32603, paste0("Tool '", nm %||% "", "' not found")))
    }
    res <- tryCatch(
      tool$handler(args),
      error = function(e) {
        structure(list(msg = conditionMessage(e)), class = "sdk_mcp_handler_error")
      }
    )
    if (inherits(res, "sdk_mcp_handler_error")) {
      return(err(-32603, res$msg))
    }
    return(ok(.sdk_mcp_normalize_result(res)))
  }

  if (identical(method, "notifications/initialized")) {
    # a notification has no id; acknowledge without one
    return(list(jsonrpc = "2.0", result = stats::setNames(list(), character(0))))
  }

  err(-32601, paste0("Method '", method %||% "", "' not found"))
}

# Handle one newline-delimited JSON-RPC line for a stdio MCP server.
# Returns the response JSON string to write back, or NULL when nothing should be
# written (a notification with no `id`, or an unparseable/blank line).
# @keywords internal
.mcp_stdio_reply <- function(server_config, line) {
  line <- trimws(line)
  if (!nzchar(line)) return(NULL)
  msg <- tryCatch(jsonlite::fromJSON(line, simplifyVector = FALSE),
                  error = function(e) NULL)
  if (!is.list(msg)) return(NULL)
  resp <- .sdk_mcp_dispatch(server_config, msg)
  # JSON-RPC notifications (no `id`) must NOT get a response.
  if (is.null(msg[["id"]])) return(NULL)
  as.character(jsonlite::toJSON(resp, auto_unbox = TRUE, null = "null"))
}

#' Serve SDK MCP tools over stdio (newline-delimited JSON-RPC)
#'
#' Runs a blocking read/serve loop that speaks the MCP stdio transport
#' (newline-delimited JSON-RPC 2.0) for a server created with
#' [create_sdk_mcp_server()]. Intended to be the body of a small `Rscript`
#' launched by the CLI as an **external stdio** MCP server (register it with
#' `type = "stdio"` in `mcp_servers`).
#'
#' Unlike an in-process (`type = "sdk"`) server, a stdio server is initialized
#' by the CLI at startup and does **not** exhibit the ~50s first-message stall
#' that in-process servers hit when the client connection idles before the first
#' message. It depends only on `jsonlite` — no `ellmer`/`curl`.
#'
#' @param server An `McpSdkServerConfig` from [create_sdk_mcp_server()].
#' @param input,output Connections to read requests from / write responses to.
#'   Default stdin/stdout. Exposed for testing.
#' @return Invisibly `NULL` when the input stream reaches EOF.
#' @export
mcp_serve_stdio <- function(server, input = NULL, output = stdout()) {
  if (is.null(input)) { input <- file("stdin", "r"); on.exit(close(input), add = TRUE) }
  repeat {
    line <- tryCatch(readLines(input, n = 1L, warn = FALSE), error = function(e) character(0))
    if (length(line) == 0L) break  # EOF
    reply <- .mcp_stdio_reply(server, line)
    if (!is.null(reply)) {
      cat(reply, "\n", sep = "", file = output)
      flush(output)
    }
  }
  invisible(NULL)
}
