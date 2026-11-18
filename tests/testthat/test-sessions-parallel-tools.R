# Parity with Python claude-agent-sdk v0.2.170: session history keeps every call
# and result of a turn that ran tools in parallel.

entry <- function(type, uuid, parent, content = NULL, ...) {
  e <- list(type = type, uuid = uuid, parentUuid = parent, sessionId = "s")
  if (!is.null(content)) e$message <- list(role = type, content = content)
  c(e, list(...))
}

parallel_turn <- function(parent, tools, result_order) {
  calls <- list()
  for (i in seq_len(tools) - 1L) {
    call <- entry("assistant", paste0("call-", i),
                  if (length(calls)) calls[[length(calls)]]$uuid else parent,
                  list(list(type = "tool_use", id = paste0("toolu_", i), name = "Read", input = list())),
                  timestamp = sprintf("2026-01-01T00:00:01.%03dZ", i))
    call$message$id <- "msg_parallel"
    calls[[length(calls) + 1L]] <- call
  }
  results <- lapply(seq_along(result_order), function(position) {
    i <- result_order[[position]]
    entry("user", paste0("result-", i), paste0("call-", i),
          list(list(type = "tool_result", tool_use_id = paste0("toolu_", i), content = "ok")),
          sourceToolAssistantUUID = paste0("call-", i),
          timestamp = sprintf("2026-01-01T00:00:02.%03dZ", position - 1L))
  })
  list(calls = calls, results = results)
}

ids_of <- function(chain, type, field) unlist(lapply(chain, function(e) {
  content <- e$message$content
  if (!is.list(content)) return(NULL)
  vapply(Filter(function(b) identical(b$type, type), content), function(b) b[[field]], "")
}))

test_that("all parallel calls and results are kept, whichever result came last", {
  for (order in list(c(0L, 1L, 2L), c(2L, 0L, 1L), c(1L, 2L, 0L))) {
    turn <- parallel_turn("prompt", 3L, order)
    last <- turn$results[[length(turn$results)]]$uuid
    entries <- c(list(entry("user", "prompt", NULL, "read them")), turn$calls, turn$results,
                 list(entry("assistant", "answer", last, "done")))
    chain <- ClaudeAgentSDK:::.build_conversation_chain(entries)
    expect_identical(ids_of(chain, "tool_use", "id"), c("toolu_0", "toolu_1", "toolu_2"))
    expect_setequal(ids_of(chain, "tool_result", "tool_use_id"), c("toolu_0", "toolu_1", "toolu_2"))
    uuids <- vapply(chain, `[[`, "", "uuid")
    expect_length(uuids, 8L)
    expect_false(anyDuplicated(uuids) > 0)
    expect_identical(uuids[[1]], "prompt")
    expect_identical(vapply(chain[2:7], `[[`, "", "type"), c(rep("assistant", 3), rep("user", 3)))
    expect_identical(uuids[[8]], "answer")
  }
})

test_that("results are recovered when the parallel turn ends the transcript", {
  turn <- parallel_turn("prompt", 2L, c(1L, 0L))
  entries <- c(list(entry("user", "prompt", NULL, "read them")), turn$calls, turn$results)
  chain <- ClaudeAgentSDK:::.build_conversation_chain(entries)
  expect_identical(vapply(chain, `[[`, "", "uuid"),
                   c("prompt", "call-0", "call-1", "result-1", "result-0"))
})

test_that("ordinary linear transcripts are unchanged", {
  entries <- list(entry("user", "u1", NULL, "hi"),
                  entry("assistant", "a1", "u1", "hello"),
                  entry("user", "u2", "a1", "bye"))
  expect_identical(vapply(ClaudeAgentSDK:::.build_conversation_chain(entries), `[[`, "", "uuid"),
                   c("u1", "a1", "u2"))
})
