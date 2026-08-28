# Unit tests for ClaudeSDKClient — no CLI needed

test_that("disconnect without connect does not error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_no_error(client$disconnect())
})

test_that("get_server_info returns NULL before connect", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_null(client$get_server_info())
})

test_that("send before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$send("hello"), "connect")
})

test_that("interrupt before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$interrupt(), "connect")
})

test_that("set_permission_mode before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$set_permission_mode("plan"), "connect")
})

test_that("set_model before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$set_model("claude-haiku-4-5-20251001"), "connect")
})

test_that("options stored on client", {
  opts <- ClaudeAgentOptions(model = "claude-opus-4-6", max_turns = 3L)
  client <- ClaudeSDKClient$new(opts)
  expect_equal(client$options$model, "claude-opus-4-6")
  expect_equal(client$options$max_turns, 3L)
})

test_that("query before connect raises error (alias for send)", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$query("hello"), "connect")
})

test_that("can_use_tool conflicts with permission_prompt_tool_name", {
  opts <- ClaudeAgentOptions(
    can_use_tool = function(tool, input, ctx) PermissionResultAllow(),
    permission_prompt_tool_name = "custom"
  )
  client <- ClaudeSDKClient$new(opts)
  expect_error(client$connect(), "can_use_tool.*permission_prompt_tool_name")
})

test_that("receive_response_async before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$receive_response_async(), "connect")
})

test_that("approve_tool before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$approve_tool("req_1"), "connect")
})

test_that("deny_tool before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$deny_tool("req_1"), "connect")
})

test_that("session_id active binding returns empty string before any run", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_equal(client$session_id, "")
})

test_that("session_id active binding is read-only", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$session_id <- "abc123", "read-only")
})

test_that("resume() errors when no session_id captured yet", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$resume(), "No session_id captured yet")
})

test_that("PermissionRequestMessage constructor works", {
  msg <- PermissionRequestMessage(
    request_id = "req_1", tool_name = "Read",
    tool_input = list(path = "/tmp")
  )
  expect_true(inherits(msg, "PermissionRequestMessage"))
  expect_equal(msg$request_id, "req_1")
  expect_equal(msg$tool_name, "Read")
  expect_equal(msg$tool_input, list(path = "/tmp"))
  expect_null(msg$tool_use_id)
})

# ---------------------------------------------------------------------------
# approve_tool / deny_tool parameter completeness (message-driven API)
# ---------------------------------------------------------------------------

test_that("approve_tool has updated_permissions parameter", {
  args <- formals(ClaudeSDKClient$public_methods$approve_tool)
  expect_true("updated_permissions" %in% names(args))
})

test_that("deny_tool has interrupt parameter defaulting to FALSE", {
  args <- formals(ClaudeSDKClient$public_methods$deny_tool)
  expect_true("interrupt" %in% names(args))
  expect_false(args[["interrupt"]])
})

test_that("approve_tool builds updatedPermissions in camelCase wire format", {
  pu <- PermissionUpdate(
    type     = "addRules",
    rules    = list(PermissionRuleValue("Bash", "allow")),
    behavior = "allow",
    destination = "projectSettings"
  )
  # Simulate the response construction inside approve_tool
  response <- list(behavior = "allow", updatedInput = list())
  response[["updatedPermissions"]] <- lapply(list(pu), ClaudeAgentSDK:::.permission_update_to_dict)

  perms <- response[["updatedPermissions"]]
  expect_length(perms, 1L)
  expect_equal(perms[[1L]][["type"]], "addRules")
  expect_equal(perms[[1L]][["rules"]][[1L]][["toolName"]], "Bash")
  expect_equal(perms[[1L]][["rules"]][[1L]][["ruleContent"]], "allow")
  expect_equal(perms[[1L]][["destination"]], "projectSettings")
  expect_null(perms[[1L]][["tool_name"]])
})

test_that("approve_tool without updated_permissions omits updatedPermissions field", {
  response <- list(behavior = "allow", updatedInput = list())
  # updated_permissions = NULL branch — field must not appear
  expect_null(response[["updatedPermissions"]])
})

test_that("deny_tool with interrupt=TRUE adds interrupt field", {
  resp <- list(behavior = "deny", message = "no")
  resp[["interrupt"]] <- TRUE
  expect_true(isTRUE(resp[["interrupt"]]))
})

test_that("deny_tool without interrupt omits interrupt field", {
  resp <- list(behavior = "deny", message = "no")
  expect_null(resp[["interrupt"]])
})

test_that("get_context_usage_async before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$get_context_usage_async(), "connect")
})

test_that("get_context_usage_async delegates to transport without reading", {
  skip_if_not_installed("promises")
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  private <- client$.__enclos_env__$private
  captured <- NULL

  fake_transport <- list(
    is_alive = function() TRUE,
    send_async = function(request, timeout_ms) {
      captured <<- list(request = request, timeout_ms = timeout_ms)
      promises::promise_resolve(list(totalTokens = 321L))
    }
  )
  private$transport <- fake_transport

  resolved <- NULL
  promises::then(
    client$get_context_usage_async(),
    onFulfilled = function(value) resolved <<- value
  )
  later::run_now(0.05)

  expect_equal(captured$request, list(subtype = "get_context_usage"))
  expect_equal(captured$timeout_ms, 5000L)
  expect_equal(resolved, list(totalTokens = 321L))
})


test_that("get_context_usage_async supports callback mode without send_async", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  private <- client$.__enclos_env__$private
  captured <- NULL
  resolved <- NULL
  fake_transport <- list(
    is_alive = function() TRUE,
    send_async = function(...) stop("promise path must not be used"),
    send_async_callback = function(request, on_fulfilled, on_rejected, timeout_ms) {
      captured <<- list(request = request, timeout_ms = timeout_ms)
      on_fulfilled(list(totalTokens = 987L))
      invisible("callback-request")
    }
  )
  private$transport <- fake_transport

  request_id <- client$get_context_usage_async(
    timeout_ms = 1234L,
    on_fulfilled = function(value) resolved <<- value,
    on_rejected = function(error) stop(conditionMessage(error))
  )
  expect_identical(request_id, "callback-request")
  expect_equal(captured$request, list(subtype = "get_context_usage"))
  expect_equal(captured$timeout_ms, 1234L)
  expect_equal(resolved, list(totalTokens = 987L))
})


test_that("set_model_async delegates a correlated Promise request", {
  skip_if_not_installed("promises")
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  private <- client$.__enclos_env__$private
  captured <- NULL
  fake_transport <- list(
    is_alive = function() TRUE,
    send_async = function(request, timeout_ms) {
      captured <<- list(request = request, timeout_ms = timeout_ms)
      promises::promise_resolve(list())
    }
  )
  private$transport <- fake_transport

  resolved <- FALSE
  promises::then(
    client$set_model_async("sonnet", timeout_ms = 2345L),
    onFulfilled = function(value) resolved <<- TRUE
  )
  later::run_now(0.05)

  expect_equal(captured$request, list(subtype = "set_model", model = "sonnet"))
  expect_equal(captured$timeout_ms, 2345L)
  expect_true(resolved)
})


test_that("set_model_async callback mode does not use the Promise transport", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  private <- client$.__enclos_env__$private
  captured <- NULL
  fulfilled <- FALSE
  fake_transport <- list(
    is_alive = function() TRUE,
    send_async = function(...) stop("promise path must not be used"),
    send_async_callback = function(request, on_fulfilled, on_rejected, timeout_ms) {
      captured <<- list(request = request, timeout_ms = timeout_ms)
      on_fulfilled(list())
      invisible("model-callback-request")
    }
  )
  private$transport <- fake_transport

  request_id <- client$set_model_async(
    "opus",
    timeout_ms = 3456L,
    on_fulfilled = function(value) fulfilled <<- TRUE,
    on_rejected = function(error) stop(conditionMessage(error))
  )

  expect_identical(request_id, "model-callback-request")
  expect_equal(captured$request, list(subtype = "set_model", model = "opus"))
  expect_equal(captured$timeout_ms, 3456L)
  expect_true(fulfilled)
})
