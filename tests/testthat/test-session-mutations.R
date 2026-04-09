# Helpers
.make_session_file <- function(dir, session_id, lines) {
  path <- file.path(dir, paste0(session_id, ".jsonl"))
  writeLines(lines, path)
  path
}

# ---------------------------------------------------------------------------
# .generate_uuid_v4
# ---------------------------------------------------------------------------

test_that(".generate_uuid_v4 produces valid UUID v4", {
  u <- ClaudeAgentSDK:::.generate_uuid_v4()
  expect_match(u, "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
})

test_that(".generate_uuid_v4 is unique across calls", {
  uuids <- replicate(100, ClaudeAgentSDK:::.generate_uuid_v4())
  expect_equal(length(unique(uuids)), 100L)
})

# ---------------------------------------------------------------------------
# .sanitize_unicode_tag
# ---------------------------------------------------------------------------

test_that(".sanitize_unicode_tag strips zero-width characters", {
  dirty <- paste0("hello", "\u200b", "world")
  clean <- ClaudeAgentSDK:::.sanitize_unicode_tag(dirty)
  expect_equal(clean, "helloworld")
})

test_that(".sanitize_unicode_tag strips BOM", {
  dirty <- paste0("\ufeff", "tag")
  clean <- ClaudeAgentSDK:::.sanitize_unicode_tag(dirty)
  expect_equal(clean, "tag")
})

test_that(".sanitize_unicode_tag leaves normal strings unchanged", {
  expect_equal(ClaudeAgentSDK:::.sanitize_unicode_tag("experiment"), "experiment")
})

# ---------------------------------------------------------------------------
# rename_session / tag_session (against a real temp directory)
# ---------------------------------------------------------------------------

test_that("rename_session appends custom-title entry", {
  tmp   <- tempdir()
  sid   <- ClaudeAgentSDK:::.generate_uuid_v4()

  # We need the file to live inside a sanitised project dir so
  # .find_session_file() can locate it via .find_project_dir()
  proj  <- ClaudeAgentSDK:::.sanitize_path(tmp)
  pdir  <- file.path(ClaudeAgentSDK:::.get_projects_dir(), proj)
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(pdir, recursive = TRUE), add = TRUE)

  .make_session_file(pdir, sid, c(
    paste0('{"type":"user","uuid":"u1","sessionId":"', sid, '","message":{"role":"user","content":"hello"}}')
  ))

  rename_session(sid, "My New Title", directory = tmp)

  written <- readLines(file.path(pdir, paste0(sid, ".jsonl")), warn = FALSE)
  last    <- jsonlite::fromJSON(tail(written, 1L), simplifyVector = FALSE)
  expect_equal(last[["type"]],        "custom-title")
  expect_equal(last[["customTitle"]], "My New Title")
  expect_equal(last[["sessionId"]],   sid)
})

test_that("rename_session rejects empty title", {
  expect_error(rename_session("00000000-0000-0000-0000-000000000000", "  "),
               "non-empty")
})

test_that("rename_session rejects invalid UUID", {
  expect_error(rename_session("not-a-uuid", "title"), "Invalid session_id")
})

test_that("tag_session appends tag entry", {
  tmp  <- tempdir()
  sid  <- ClaudeAgentSDK:::.generate_uuid_v4()
  proj <- ClaudeAgentSDK:::.sanitize_path(tmp)
  pdir <- file.path(ClaudeAgentSDK:::.get_projects_dir(), proj)
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(pdir, recursive = TRUE), add = TRUE)

  .make_session_file(pdir, sid, c(
    paste0('{"type":"user","uuid":"u1","sessionId":"', sid, '","message":{"role":"user","content":"hi"}}')
  ))

  tag_session(sid, "experiment", directory = tmp)

  written <- readLines(file.path(pdir, paste0(sid, ".jsonl")), warn = FALSE)
  last    <- jsonlite::fromJSON(tail(written, 1L), simplifyVector = FALSE)
  expect_equal(last[["type"]],      "tag")
  expect_equal(last[["tag"]],       "experiment")
  expect_equal(last[["sessionId"]], sid)
})

test_that("tag_session with NULL clears the tag (empty string)", {
  tmp  <- tempdir()
  sid  <- ClaudeAgentSDK:::.generate_uuid_v4()
  proj <- ClaudeAgentSDK:::.sanitize_path(tmp)
  pdir <- file.path(ClaudeAgentSDK:::.get_projects_dir(), proj)
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(pdir, recursive = TRUE), add = TRUE)

  .make_session_file(pdir, sid, c(
    paste0('{"type":"user","uuid":"u1","sessionId":"', sid, '","message":{"role":"user","content":"hi"}}')
  ))

  tag_session(sid, NULL, directory = tmp)

  written <- readLines(file.path(pdir, paste0(sid, ".jsonl")), warn = FALSE)
  last    <- jsonlite::fromJSON(tail(written, 1L), simplifyVector = FALSE)
  expect_equal(last[["tag"]], "")
})

# ---------------------------------------------------------------------------
# delete_session
# ---------------------------------------------------------------------------

test_that("delete_session removes the JSONL file", {
  tmp  <- tempdir()
  sid  <- ClaudeAgentSDK:::.generate_uuid_v4()
  proj <- ClaudeAgentSDK:::.sanitize_path(tmp)
  pdir <- file.path(ClaudeAgentSDK:::.get_projects_dir(), proj)
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(pdir, recursive = TRUE), add = TRUE)

  path <- .make_session_file(pdir, sid, c(
    paste0('{"type":"user","uuid":"u1","sessionId":"', sid, '","message":{"role":"user","content":"bye"}}')
  ))
  expect_true(file.exists(path))

  delete_session(sid, directory = tmp)
  expect_false(file.exists(path))
})

test_that("delete_session errors when session not found", {
  sid <- ClaudeAgentSDK:::.generate_uuid_v4()
  expect_error(delete_session(sid), "not found")
})

test_that("delete_session rejects invalid UUID", {
  expect_error(delete_session("bad-uuid"), "Invalid session_id")
})

# ---------------------------------------------------------------------------
# fork_session
# ---------------------------------------------------------------------------

test_that("fork_session creates a new JSONL with remapped UUIDs", {
  tmp  <- tempdir()
  sid  <- ClaudeAgentSDK:::.generate_uuid_v4()
  proj <- ClaudeAgentSDK:::.sanitize_path(tmp)
  pdir <- file.path(ClaudeAgentSDK:::.get_projects_dir(), proj)
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(pdir, recursive = TRUE), add = TRUE)

  u1 <- ClaudeAgentSDK:::.generate_uuid_v4()
  u2 <- ClaudeAgentSDK:::.generate_uuid_v4()
  .make_session_file(pdir, sid, c(
    paste0('{"type":"user","uuid":"', u1, '","sessionId":"', sid,
           '","parentUuid":null,"message":{"role":"user","content":"hello"}}'),
    paste0('{"type":"assistant","uuid":"', u2, '","sessionId":"', sid,
           '","parentUuid":"', u1, '","message":{"role":"assistant","content":[{"type":"text","text":"hi"}],"model":"m"}}')
  ))

  result <- fork_session(sid, directory = tmp)
  expect_true(nzchar(result$session_id))
  expect_false(identical(result$session_id, sid))

  # Verify fork file exists and contains remapped UUIDs
  fork_path <- file.path(pdir, paste0(result$session_id, ".jsonl"))
  expect_true(file.exists(fork_path))

  fork_lines <- readLines(fork_path, warn = FALSE)
  # Should have 2 messages + custom-title
  expect_gte(length(fork_lines), 3L)

  first <- jsonlite::fromJSON(fork_lines[[1L]], simplifyVector = FALSE)
  expect_false(identical(first[["uuid"]], u1))           # UUID remapped
  expect_equal(first[["sessionId"]], result$session_id) # new session ID
  expect_equal(first[["forkedFrom"]][["sessionId"]], sid)

  last <- jsonlite::fromJSON(tail(fork_lines, 1L), simplifyVector = FALSE)
  expect_equal(last[["type"]], "custom-title")
  expect_true(grepl("fork", last[["customTitle"]], ignore.case = TRUE))
})

test_that("fork_session respects up_to_message_id", {
  tmp  <- tempdir()
  sid  <- ClaudeAgentSDK:::.generate_uuid_v4()
  proj <- ClaudeAgentSDK:::.sanitize_path(tmp)
  pdir <- file.path(ClaudeAgentSDK:::.get_projects_dir(), proj)
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(pdir, recursive = TRUE), add = TRUE)

  u1 <- ClaudeAgentSDK:::.generate_uuid_v4()
  u2 <- ClaudeAgentSDK:::.generate_uuid_v4()
  u3 <- ClaudeAgentSDK:::.generate_uuid_v4()
  .make_session_file(pdir, sid, c(
    paste0('{"type":"user","uuid":"', u1, '","sessionId":"', sid, '","parentUuid":null,"message":{"role":"user","content":"q1"}}'),
    paste0('{"type":"assistant","uuid":"', u2, '","sessionId":"', sid, '","parentUuid":"', u1, '","message":{"role":"assistant","content":[{"type":"text","text":"a1"}],"model":"m"}}'),
    paste0('{"type":"user","uuid":"', u3, '","sessionId":"', sid, '","parentUuid":"', u2, '","message":{"role":"user","content":"q2"}}')
  ))

  result <- fork_session(sid, directory = tmp, up_to_message_id = u2)
  fork_path <- file.path(pdir, paste0(result$session_id, ".jsonl"))
  fork_lines <- readLines(fork_path, warn = FALSE)

  # Only u1 and u2 messages (+ custom-title); u3 excluded
  msg_lines <- Filter(function(l) {
    obj <- tryCatch(jsonlite::fromJSON(l, simplifyVector = FALSE), error = function(e) NULL)
    !is.null(obj) && obj[["type"]] %in% c("user", "assistant")
  }, fork_lines)
  expect_equal(length(msg_lines), 2L)
})

test_that("fork_session accepts custom title", {
  tmp  <- tempdir()
  sid  <- ClaudeAgentSDK:::.generate_uuid_v4()
  proj <- ClaudeAgentSDK:::.sanitize_path(tmp)
  pdir <- file.path(ClaudeAgentSDK:::.get_projects_dir(), proj)
  dir.create(pdir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(pdir, recursive = TRUE), add = TRUE)

  u1 <- ClaudeAgentSDK:::.generate_uuid_v4()
  .make_session_file(pdir, sid, c(
    paste0('{"type":"user","uuid":"', u1, '","sessionId":"', sid, '","parentUuid":null,"message":{"role":"user","content":"hi"}}')
  ))

  result <- fork_session(sid, directory = tmp, title = "My Fork Title")
  fork_lines <- readLines(file.path(pdir, paste0(result$session_id, ".jsonl")), warn = FALSE)
  last <- jsonlite::fromJSON(tail(fork_lines, 1L), simplifyVector = FALSE)
  expect_equal(last[["customTitle"]], "My Fork Title")
})

test_that("fork_session rejects invalid session_id", {
  expect_error(fork_session("not-a-uuid"), "Invalid session_id")
})

test_that("fork_session rejects invalid up_to_message_id", {
  sid <- ClaudeAgentSDK:::.generate_uuid_v4()
  expect_error(fork_session(sid, up_to_message_id = "bad"), "Invalid up_to_message_id")
})
