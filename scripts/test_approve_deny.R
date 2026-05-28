#!/usr/bin/env Rscript
# Test script: verify current state of approve_tool / deny_tool
# and PermissionUpdate wire serialization.
#
# Runs WITHOUT a live CLI — tests internal logic only.

library(ClaudeAgentSDK)

ok   <- 0L
fail <- 0L

check <- function(label, expr) {
  result <- tryCatch(expr, error = function(e) {
    cat(sprintf("[FAIL] %s\n  Error: %s\n", label, conditionMessage(e)))
    fail <<- fail + 1L
    NULL
  })
  if (!is.null(result) && isTRUE(result)) {
    cat(sprintf("[PASS] %s\n", label))
    ok <<- ok + 1L
  } else if (!is.null(result) && !isTRUE(result)) {
    cat(sprintf("[FAIL] %s\n  Got: %s\n", label, paste(capture.output(str(result)), collapse="")))
    fail <<- fail + 1L
  }
}

cat("=== approve_tool / deny_tool parameter audit ===\n\n")

# ---- 1. approve_tool signature ----
cat("-- approve_tool signature --\n")
args_approve <- formals(ClaudeSDKClient$public_methods$approve_tool)
check("approve_tool has request_id param",    "request_id"          %in% names(args_approve))
check("approve_tool has updated_input param", "updated_input"       %in% names(args_approve))
check("approve_tool has updated_permissions param (NEW)",
      "updated_permissions" %in% names(args_approve))

# ---- 2. deny_tool signature ----
cat("\n-- deny_tool signature --\n")
args_deny <- formals(ClaudeSDKClient$public_methods$deny_tool)
check("deny_tool has request_id param", "request_id" %in% names(args_deny))
check("deny_tool has message param",    "message"    %in% names(args_deny))
check("deny_tool has interrupt param (NEW)",
      "interrupt"  %in% names(args_deny))

# ---- 3. .permission_update_to_dict camelCase ----
cat("\n-- .permission_update_to_dict camelCase output --\n")
pu <- PermissionUpdate(
  type     = "addRules",
  rules    = list(PermissionRuleValue("Bash", "allow")),
  behavior = "allow"
)
d <- ClaudeAgentSDK:::.permission_update_to_dict(pu)
check("addRules: type field",          identical(d[["type"]], "addRules"))
check("addRules: rules[[1]] toolName", identical(d[["rules"]][[1L]][["toolName"]], "Bash"))
check("addRules: rules[[1]] ruleContent", identical(d[["rules"]][[1L]][["ruleContent"]], "allow"))
check("addRules: no snake_case tool_name leaks", is.null(d[["tool_name"]]))

pu2 <- PermissionUpdate(type = "setMode", mode = "acceptEdits", destination = "session")
d2  <- ClaudeAgentSDK:::.permission_update_to_dict(pu2)
check("setMode: mode field", identical(d2[["mode"]], "acceptEdits"))
check("setMode: destination field", identical(d2[["destination"]], "session"))
check("setMode: no rules field", is.null(d2[["rules"]]))

pu3 <- PermissionUpdate(type = "addDirectories", directories = c("/tmp"))
d3  <- ClaudeAgentSDK:::.permission_update_to_dict(pu3)
check("addDirectories: directories field", identical(d3[["directories"]], "/tmp"))

# ---- 4. approve_tool response building (simulated) ----
cat("\n-- approve_tool response wire format (simulated) --\n")

# Simulate what approve_tool should build when updated_permissions given
build_approve_response <- function(updated_input, updated_permissions = NULL) {
  resp <- list(behavior = "allow", updatedInput = updated_input)
  if (!is.null(updated_permissions)) {
    resp[["updatedPermissions"]] <- lapply(updated_permissions, ClaudeAgentSDK:::.permission_update_to_dict)
  }
  resp
}

resp_plain <- build_approve_response(list(command = "ls"))
check("plain approve: behavior=allow",     identical(resp_plain[["behavior"]], "allow"))
check("plain approve: no updatedPermissions", is.null(resp_plain[["updatedPermissions"]]))

resp_with_perm <- build_approve_response(
  updated_input       = list(command = "ls"),
  updated_permissions = list(PermissionUpdate("addRules",
    rules = list(PermissionRuleValue("Bash", "allow ls")),
    behavior = "allow"
  ))
)
check("approve+perms: updatedPermissions present",
      !is.null(resp_with_perm[["updatedPermissions"]]))
check("approve+perms: toolName is camelCase",
      identical(resp_with_perm[["updatedPermissions"]][[1L]][["rules"]][[1L]][["toolName"]], "Bash"))
check("approve+perms: no snake_case in wire",
      is.null(resp_with_perm[["updatedPermissions"]][[1L]][["rules"]][[1L]][["tool_name"]]))

# ---- 5. deny_tool response building (simulated) ----
cat("\n-- deny_tool response wire format (simulated) --\n")

build_deny_response <- function(message, interrupt = FALSE) {
  resp <- list(behavior = "deny", message = message)
  if (isTRUE(interrupt)) resp[["interrupt"]] <- TRUE
  resp
}

resp_deny <- build_deny_response("Not allowed")
check("plain deny: behavior=deny",         identical(resp_deny[["behavior"]], "deny"))
check("plain deny: no interrupt field",    is.null(resp_deny[["interrupt"]]))

resp_deny_int <- build_deny_response("Abort everything", interrupt = TRUE)
check("deny+interrupt: interrupt=TRUE",    isTRUE(resp_deny_int[["interrupt"]]))

# ---- 6. HookMatcher optional params ----
cat("\n-- HookMatcher optional params --\n")
m1 <- HookMatcher(hooks = list(function(...) list()))
check("HookMatcher: matcher defaults NULL", is.null(m1$matcher))
m2 <- HookMatcher(matcher = "Bash")
check("HookMatcher: hooks defaults list()", identical(m2$hooks, list()))
m3 <- HookMatcher()
check("HookMatcher: fully empty call OK",   is.list(m3))

# ---- 7. _simple_hash Python parity ----
cat("\n-- _simple_hash signed-32-bit parity --\n")
check("hash '/tmp/test' == 'udbo7b'",          identical(ClaudeAgentSDK:::.simple_hash("/tmp/test"), "udbo7b"))
check("hash 'a'*300 == 'rn408w' (overflow)",   identical(ClaudeAgentSDK:::.simple_hash(strrep("a", 300L)), "rn408w"))
check("hash 'hello' == '1n1e4y'",             identical(ClaudeAgentSDK:::.simple_hash("hello"), "1n1e4y"))

cat(sprintf("\n=== %d passed / %d failed ===\n", ok, fail))
if (fail > 0L) quit(status = 1L)
