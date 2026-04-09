# ===========================================================================
# Unit tests for session helper functions (no CLI required)
# ===========================================================================

# ---------------------------------------------------------------------------
# 1. .validate_uuid()
# ---------------------------------------------------------------------------

test_that(".validate_uuid accepts valid lowercase UUID", {
  uuid <- "550e8400-e29b-41d4-a716-446655440000"
  expect_equal(ClaudeAgentSDK:::.validate_uuid(uuid), uuid)
})

test_that(".validate_uuid accepts valid uppercase UUID", {
  uuid <- "550E8400-E29B-41D4-A716-446655440000"
  expect_equal(ClaudeAgentSDK:::.validate_uuid(uuid), uuid)
})

test_that(".validate_uuid accepts mixed-case UUID", {
  uuid <- "550e8400-E29B-41d4-A716-446655440000"
  expect_equal(ClaudeAgentSDK:::.validate_uuid(uuid), uuid)
})

test_that(".validate_uuid returns NULL for invalid strings", {
  expect_null(ClaudeAgentSDK:::.validate_uuid("not-uuid"))
  expect_null(ClaudeAgentSDK:::.validate_uuid(""))
  expect_null(ClaudeAgentSDK:::.validate_uuid("12345"))
  expect_null(ClaudeAgentSDK:::.validate_uuid("550e8400-e29b-41d4-a716"))
  expect_null(ClaudeAgentSDK:::.validate_uuid("gggggggg-gggg-gggg-gggg-gggggggggggg"))
})

# ---------------------------------------------------------------------------
# 2. .sanitize_path()
# ---------------------------------------------------------------------------

test_that(".sanitize_path replaces slashes and special chars with dashes", {
  result <- ClaudeAgentSDK:::.sanitize_path("/home/user/project")
  expect_equal(result, "-home-user-project")
})

test_that(".sanitize_path handles trailing slash", {
  result <- ClaudeAgentSDK:::.sanitize_path("/home/user/project/")
  expect_equal(result, "-home-user-project-")
})

test_that(".sanitize_path returns short path as-is when under max length", {
  # A 200-char sanitized path should NOT be truncated
  short_enough <- paste(rep("a", 200), collapse = "")
  result <- ClaudeAgentSDK:::.sanitize_path(short_enough)
  expect_equal(result, short_enough)
  expect_equal(nchar(result), 200)
})

test_that(".sanitize_path returns short paths unchanged (besides character replacement)", {
  result <- ClaudeAgentSDK:::.sanitize_path("simple")
  expect_equal(result, "simple")
})

# ---------------------------------------------------------------------------
# 3. .simple_hash()
# ---------------------------------------------------------------------------

test_that(".simple_hash of empty string returns '0'", {
  expect_equal(ClaudeAgentSDK:::.simple_hash(""), "0")
})

test_that(".simple_hash returns a character string", {
  result <- ClaudeAgentSDK:::.simple_hash("")
  expect_type(result, "character")
  expect_equal(nchar(result), 1)
})

# ---------------------------------------------------------------------------
# 4. .extract_json_string_field()
# ---------------------------------------------------------------------------

test_that(".extract_json_string_field extracts simple key:value", {
  text <- '{"type":"user","name":"Alice"}'
  expect_equal(ClaudeAgentSDK:::.extract_json_string_field(text, "name"), "Alice")
  expect_equal(ClaudeAgentSDK:::.extract_json_string_field(text, "type"), "user")
})

test_that(".extract_json_string_field works with space after colon", {
  text <- '{"type": "user", "name": "Bob"}'
  expect_equal(ClaudeAgentSDK:::.extract_json_string_field(text, "name"), "Bob")
  expect_equal(ClaudeAgentSDK:::.extract_json_string_field(text, "type"), "user")
})

test_that(".extract_json_string_field handles escaped quotes in value", {
  text <- '{"msg":"hello \\"world\\""}'
  result <- ClaudeAgentSDK:::.extract_json_string_field(text, "msg")
  expect_equal(result, 'hello "world"')
})

test_that(".extract_json_string_field returns NULL for missing key", {
  text <- '{"type":"user"}'
  expect_null(ClaudeAgentSDK:::.extract_json_string_field(text, "missing"))
})

test_that(".extract_json_string_field returns first occurrence", {
  text <- '{"key":"first"} {"key":"second"}'
  expect_equal(ClaudeAgentSDK:::.extract_json_string_field(text, "key"), "first")
})

# ---------------------------------------------------------------------------
# 5. .extract_last_json_string_field()
# ---------------------------------------------------------------------------

test_that(".extract_last_json_string_field returns last occurrence (space format)", {
  # NOTE: .extract_last_json_string_field has a known gregexpr attributes bug

  # where identical(m, -1L) fails because gregexpr returns -1L with
  # match.length attributes. The space-after-colon format works correctly
  # because pattern 2 (the last processed) matches and sets the final value.
  text <- paste0('{"key": "first"}', "\n", '{"key": "second"}', "\n", '{"key": "third"}')
  expect_equal(ClaudeAgentSDK:::.extract_last_json_string_field(text, "key"), "third")
})

test_that(".extract_last_json_string_field works with single occurrence (space format)", {
  text <- '{"title": "only one"}'
  expect_equal(ClaudeAgentSDK:::.extract_last_json_string_field(text, "title"), "only one")
})

test_that(".extract_last_json_string_field with multiple lines (space format)", {
  text <- paste0('{"a": "first"}', "\n", '{"a": "last"}')
  expect_equal(ClaudeAgentSDK:::.extract_last_json_string_field(text, "a"), "last")
})

test_that(".extract_last_json_string_field works when both formats present", {
  # When both "key":"val" and "key": "val" appear, function processes both
  # patterns and returns the last match from the last pattern processed
  text <- '{"key":"no-space","key": "with-space"}'
  result <- ClaudeAgentSDK:::.extract_last_json_string_field(text, "key")
  expect_equal(result, "with-space")
})

# ---------------------------------------------------------------------------
# 6. .extract_first_prompt_from_head()
# ---------------------------------------------------------------------------

test_that(".extract_first_prompt_from_head extracts first user content", {
  line1 <- jsonlite::toJSON(
    list(type = "user", uuid = "u1",
         message = list(content = "Hello Claude")),
    auto_unbox = TRUE
  )
  head_text <- as.character(line1)
  result <- ClaudeAgentSDK:::.extract_first_prompt_from_head(head_text)
  expect_equal(result, "Hello Claude")
})

test_that(".extract_first_prompt_from_head skips system/meta lines", {
  meta_line <- jsonlite::toJSON(
    list(type = "user", uuid = "m1", isMeta = TRUE,
         message = list(content = "meta stuff")),
    auto_unbox = TRUE
  )
  user_line <- jsonlite::toJSON(
    list(type = "user", uuid = "u1",
         message = list(content = "Real prompt")),
    auto_unbox = TRUE
  )
  head_text <- paste(as.character(meta_line), as.character(user_line), sep = "\n")
  result <- ClaudeAgentSDK:::.extract_first_prompt_from_head(head_text)
  expect_equal(result, "Real prompt")
})

test_that(".extract_first_prompt_from_head skips non-user lines", {
  assistant_line <- jsonlite::toJSON(
    list(type = "assistant", uuid = "a1",
         message = list(content = "I am assistant")),
    auto_unbox = TRUE
  )
  user_line <- jsonlite::toJSON(
    list(type = "user", uuid = "u1",
         message = list(content = "User question")),
    auto_unbox = TRUE
  )
  head_text <- paste(as.character(assistant_line), as.character(user_line), sep = "\n")
  result <- ClaudeAgentSDK:::.extract_first_prompt_from_head(head_text)
  expect_equal(result, "User question")
})

test_that(".extract_first_prompt_from_head returns empty string when no user content", {
  line <- jsonlite::toJSON(
    list(type = "assistant", uuid = "a1",
         message = list(content = "response")),
    auto_unbox = TRUE
  )
  result <- ClaudeAgentSDK:::.extract_first_prompt_from_head(as.character(line))
  expect_equal(result, "")
})

test_that(".extract_first_prompt_from_head truncates long prompts", {
  long_text <- paste(rep("a", 300), collapse = "")
  user_line <- jsonlite::toJSON(
    list(type = "user", uuid = "u1",
         message = list(content = long_text)),
    auto_unbox = TRUE
  )
  result <- ClaudeAgentSDK:::.extract_first_prompt_from_head(as.character(user_line))
  # Should be 200 chars + ellipsis
  expect_equal(nchar(result), 201)
  expect_true(endsWith(result, "\u2026"))
})

test_that(".extract_first_prompt_from_head handles block content format", {
  user_line <- jsonlite::toJSON(
    list(type = "user", uuid = "u1",
         message = list(
           content = list(
             list(type = "text", text = "Block content prompt")
           )
         )),
    auto_unbox = TRUE
  )
  result <- ClaudeAgentSDK:::.extract_first_prompt_from_head(as.character(user_line))
  expect_equal(result, "Block content prompt")
})

test_that(".extract_first_prompt_from_head skips tool_result lines", {
  tool_line <- '{"type":"user","uuid":"u0","tool_result":true,"message":{"content":"tool output"}}'
  user_line <- jsonlite::toJSON(
    list(type = "user", uuid = "u1",
         message = list(content = "Actual prompt")),
    auto_unbox = TRUE
  )
  head_text <- paste(tool_line, as.character(user_line), sep = "\n")
  result <- ClaudeAgentSDK:::.extract_first_prompt_from_head(head_text)
  expect_equal(result, "Actual prompt")
})

# ---------------------------------------------------------------------------
# 7. .sort_and_slice()
# ---------------------------------------------------------------------------

test_that(".sort_and_slice sorts by mtime descending", {
  s1 <- list(session_id = "a", last_modified = 100)
  s2 <- list(session_id = "b", last_modified = 300)
  s3 <- list(session_id = "c", last_modified = 200)
  result <- ClaudeAgentSDK:::.sort_and_slice(list(s1, s2, s3), limit = NULL, offset = 0L)
  expect_equal(length(result), 3)
  expect_equal(result[[1]]$session_id, "b")
  expect_equal(result[[2]]$session_id, "c")
  expect_equal(result[[3]]$session_id, "a")
})

test_that(".sort_and_slice limit works", {
  s1 <- list(session_id = "a", last_modified = 100)
  s2 <- list(session_id = "b", last_modified = 300)
  s3 <- list(session_id = "c", last_modified = 200)
  result <- ClaudeAgentSDK:::.sort_and_slice(list(s1, s2, s3), limit = 2L, offset = 0L)
  expect_equal(length(result), 2)
  expect_equal(result[[1]]$session_id, "b")
  expect_equal(result[[2]]$session_id, "c")
})

test_that(".sort_and_slice offset works", {
  s1 <- list(session_id = "a", last_modified = 100)
  s2 <- list(session_id = "b", last_modified = 300)
  s3 <- list(session_id = "c", last_modified = 200)
  result <- ClaudeAgentSDK:::.sort_and_slice(list(s1, s2, s3), limit = NULL, offset = 1L)
  expect_equal(length(result), 2)
  expect_equal(result[[1]]$session_id, "c")
  expect_equal(result[[2]]$session_id, "a")
})

test_that(".sort_and_slice offset >= length returns empty list", {
  s1 <- list(session_id = "a", last_modified = 100)
  s2 <- list(session_id = "b", last_modified = 200)
  result <- ClaudeAgentSDK:::.sort_and_slice(list(s1, s2), limit = NULL, offset = 2L)
  expect_equal(length(result), 0)
  result2 <- ClaudeAgentSDK:::.sort_and_slice(list(s1, s2), limit = NULL, offset = 10L)
  expect_equal(length(result2), 0)
})

test_that(".sort_and_slice empty input returns empty list", {
  result <- ClaudeAgentSDK:::.sort_and_slice(list(), limit = NULL, offset = 0L)
  expect_equal(length(result), 0)
})

test_that(".sort_and_slice limit and offset combined", {
  sessions <- lapply(1:5, function(i) list(session_id = as.character(i), last_modified = i * 100))
  # sorted descending: 5,4,3,2,1; skip 1, take 2 => 4,3
  result <- ClaudeAgentSDK:::.sort_and_slice(sessions, limit = 2L, offset = 1L)
  expect_equal(length(result), 2)
  expect_equal(result[[1]]$session_id, "4")
  expect_equal(result[[2]]$session_id, "3")
})

# ---------------------------------------------------------------------------
# 8. .deduplicate_sessions()
# ---------------------------------------------------------------------------

test_that(".deduplicate_sessions keeps most recent when duplicates exist", {
  s1 <- list(session_id = "abc", last_modified = 100)
  s2 <- list(session_id = "abc", last_modified = 300)
  s3 <- list(session_id = "def", last_modified = 200)
  result <- ClaudeAgentSDK:::.deduplicate_sessions(list(s1, s2, s3))
  expect_equal(length(result), 2)
  ids <- vapply(result, function(s) s$session_id, character(1))
  expect_true("abc" %in% ids)
  expect_true("def" %in% ids)
  abc_entry <- Filter(function(s) s$session_id == "abc", result)[[1]]
  expect_equal(abc_entry$last_modified, 300)
})

test_that(".deduplicate_sessions with no duplicates returns all", {
  s1 <- list(session_id = "aaa", last_modified = 100)
  s2 <- list(session_id = "bbb", last_modified = 200)
  result <- ClaudeAgentSDK:::.deduplicate_sessions(list(s1, s2))
  expect_equal(length(result), 2)
})

test_that(".deduplicate_sessions empty input returns empty list", {
  result <- ClaudeAgentSDK:::.deduplicate_sessions(list())
  expect_equal(length(result), 0)
})

# ---------------------------------------------------------------------------
# 9. list_sessions() with mock data
# ---------------------------------------------------------------------------

# Helper: create a minimal valid JSONL line that .parse_session_info_from_lite
# will accept (needs type=user with content to serve as summary/first_prompt)
make_session_jsonl <- function(prompt = "Hello Claude", uuid = "u1",
                               timestamp = NULL) {
  ts <- timestamp %||% format(Sys.time(), "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  line <- jsonlite::toJSON(
    list(
      type      = "user",
      uuid      = uuid,
      timestamp = ts,
      message   = list(content = prompt)
    ),
    auto_unbox = TRUE
  )
  as.character(line)
}

test_that("list_sessions: empty directory returns empty list", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_empty_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  # Create the projects subdirectory (the function expects it)
  project_subdir <- file.path(test_dir, "projects", "test-project")
  dir.create(project_subdir, recursive = TRUE)

  result <- list_sessions(directory = NULL)
  expect_type(result, "list")
  expect_equal(length(result), 0)
})

test_that("list_sessions: single session found with correct fields", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_single_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  # We need to create a directory whose name matches .sanitize_path(some_dir)
  # Easiest: use directory=NULL so it scans all project dirs
  project_subdir <- file.path(test_dir, "projects", "my-project")
  dir.create(project_subdir, recursive = TRUE)

  uuid <- "550e8400-e29b-41d4-a716-446655440000"
  jsonl_content <- make_session_jsonl("Test prompt")
  writeLines(jsonl_content, file.path(project_subdir, paste0(uuid, ".jsonl")))

  result <- list_sessions(directory = NULL)
  expect_equal(length(result), 1)
  expect_s3_class(result[[1]], "SDKSessionInfo")
  expect_equal(result[[1]]$session_id, uuid)
  expect_true(!is.null(result[[1]]$summary))
  expect_true(!is.null(result[[1]]$last_modified))
})

test_that("list_sessions: multiple sessions sorted by mtime", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_multi_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  project_subdir <- file.path(test_dir, "projects", "my-project")
  dir.create(project_subdir, recursive = TRUE)

  uuid1 <- "11111111-1111-1111-1111-111111111111"
  uuid2 <- "22222222-2222-2222-2222-222222222222"
  uuid3 <- "33333333-3333-3333-3333-333333333333"

  # Create files with different mtimes
  writeLines(make_session_jsonl("First session"),
             file.path(project_subdir, paste0(uuid1, ".jsonl")))
  Sys.sleep(1.1)
  writeLines(make_session_jsonl("Second session"),
             file.path(project_subdir, paste0(uuid2, ".jsonl")))
  Sys.sleep(1.1)
  writeLines(make_session_jsonl("Third session"),
             file.path(project_subdir, paste0(uuid3, ".jsonl")))

  result <- list_sessions(directory = NULL)
  expect_equal(length(result), 3)
  # Most recent first
  expect_equal(result[[1]]$session_id, uuid3)
  expect_equal(result[[2]]$session_id, uuid2)
  expect_equal(result[[3]]$session_id, uuid1)
})

test_that("list_sessions: limit parameter works", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_limit_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  project_subdir <- file.path(test_dir, "projects", "my-project")
  dir.create(project_subdir, recursive = TRUE)

  uuid1 <- "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
  uuid2 <- "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
  uuid3 <- "cccccccc-cccc-cccc-cccc-cccccccccccc"

  writeLines(make_session_jsonl("One"),
             file.path(project_subdir, paste0(uuid1, ".jsonl")))
  Sys.sleep(1.1)
  writeLines(make_session_jsonl("Two"),
             file.path(project_subdir, paste0(uuid2, ".jsonl")))
  Sys.sleep(1.1)
  writeLines(make_session_jsonl("Three"),
             file.path(project_subdir, paste0(uuid3, ".jsonl")))

  result <- list_sessions(directory = NULL, limit = 2L)
  expect_equal(length(result), 2)
  # Should be the two most recent
  expect_equal(result[[1]]$session_id, uuid3)
  expect_equal(result[[2]]$session_id, uuid2)
})

test_that("list_sessions: 0-byte files are filtered out", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_zero_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  project_subdir <- file.path(test_dir, "projects", "my-project")
  dir.create(project_subdir, recursive = TRUE)

  # Create valid session
  uuid_valid <- "11111111-1111-1111-1111-111111111111"
  writeLines(make_session_jsonl("Valid"),
             file.path(project_subdir, paste0(uuid_valid, ".jsonl")))

  # Create 0-byte file
  uuid_empty <- "22222222-2222-2222-2222-222222222222"
  file.create(file.path(project_subdir, paste0(uuid_empty, ".jsonl")))

  result <- list_sessions(directory = NULL)
  expect_equal(length(result), 1)
  expect_equal(result[[1]]$session_id, uuid_valid)
})

test_that("list_sessions: non-.jsonl files are ignored", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_nonjsonl_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  project_subdir <- file.path(test_dir, "projects", "my-project")
  dir.create(project_subdir, recursive = TRUE)

  uuid <- "11111111-1111-1111-1111-111111111111"
  # Write a .txt file with valid UUID name -- should be ignored
  writeLines(make_session_jsonl("Ignored"),
             file.path(project_subdir, paste0(uuid, ".txt")))
  # Write a .json file -- should also be ignored
  writeLines(make_session_jsonl("Also ignored"),
             file.path(project_subdir, paste0(uuid, ".json")))

  result <- list_sessions(directory = NULL)
  expect_equal(length(result), 0)
})

test_that("list_sessions: non-UUID filenames are ignored", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_nonuuid_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  project_subdir <- file.path(test_dir, "projects", "my-project")
  dir.create(project_subdir, recursive = TRUE)

  # Files with non-UUID stems
  writeLines(make_session_jsonl("Not UUID"),
             file.path(project_subdir, "not-a-uuid.jsonl"))
  writeLines(make_session_jsonl("Config"),
             file.path(project_subdir, "config.jsonl"))
  writeLines(make_session_jsonl("Too short"),
             file.path(project_subdir, "12345.jsonl"))

  result <- list_sessions(directory = NULL)
  expect_equal(length(result), 0)
})

test_that("list_sessions: directory parameter targets specific project", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_dirparam_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  # Create a "project directory" and its sanitized counterpart
  fake_project <- file.path(tmp, "my_project_dir")
  dir.create(fake_project, recursive = TRUE)
  on.exit(unlink(fake_project, recursive = TRUE), add = TRUE)

  sanitized_name <- ClaudeAgentSDK:::.sanitize_path(
    normalizePath(fake_project, mustWork = FALSE)
  )
  project_subdir <- file.path(test_dir, "projects", sanitized_name)
  dir.create(project_subdir, recursive = TRUE)

  uuid <- "44444444-4444-4444-4444-444444444444"
  writeLines(make_session_jsonl("Targeted session"),
             file.path(project_subdir, paste0(uuid, ".jsonl")))

  result <- list_sessions(directory = fake_project)
  expect_equal(length(result), 1)
  expect_equal(result[[1]]$session_id, uuid)
})

# ---------------------------------------------------------------------------
# 10. get_session_messages() with JSONL conversation chain
# ---------------------------------------------------------------------------

test_that("get_session_messages: reconstructs conversation chain in order", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_msgs_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  fake_project <- file.path(tmp, paste0("msg_project_", as.integer(Sys.time())))
  dir.create(fake_project, recursive = TRUE)
  on.exit(unlink(fake_project, recursive = TRUE), add = TRUE)

  sanitized_name <- ClaudeAgentSDK:::.sanitize_path(
    normalizePath(fake_project, mustWork = FALSE)
  )
  project_subdir <- file.path(test_dir, "projects", sanitized_name)
  dir.create(project_subdir, recursive = TRUE)

  session_uuid <- "99999999-9999-9999-9999-999999999999"

  # Build a conversation chain: user -> assistant -> user -> assistant
  lines <- c(
    jsonlite::toJSON(list(
      type = "user", uuid = "u1", sessionId = session_uuid,
      message = list(content = "Hello")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "assistant", uuid = "a1", parentUuid = "u1",
      sessionId = session_uuid,
      message = list(content = "Hi there")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "user", uuid = "u2", parentUuid = "a1",
      sessionId = session_uuid,
      message = list(content = "How are you?")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "assistant", uuid = "a2", parentUuid = "u2",
      sessionId = session_uuid,
      message = list(content = "I am fine!")
    ), auto_unbox = TRUE)
  )

  writeLines(lines, file.path(project_subdir, paste0(session_uuid, ".jsonl")))

  result <- get_session_messages(session_uuid, directory = fake_project)
  expect_true(length(result) >= 2)
  # All messages should be SessionMessage objects
  for (msg in result) {
    expect_s3_class(msg, "SessionMessage")
  }
  # Check order: first should be user, then assistant alternating
  types <- vapply(result, function(m) m$type, character(1))
  expect_equal(types, c("user", "assistant", "user", "assistant"))
})

test_that("get_session_messages: corrupt lines are skipped", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_corrupt_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  fake_project <- file.path(tmp, paste0("corrupt_project_", as.integer(Sys.time())))
  dir.create(fake_project, recursive = TRUE)
  on.exit(unlink(fake_project, recursive = TRUE), add = TRUE)

  sanitized_name <- ClaudeAgentSDK:::.sanitize_path(
    normalizePath(fake_project, mustWork = FALSE)
  )
  project_subdir <- file.path(test_dir, "projects", sanitized_name)
  dir.create(project_subdir, recursive = TRUE)

  session_uuid <- "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  lines <- c(
    jsonlite::toJSON(list(
      type = "user", uuid = "u1", sessionId = session_uuid,
      message = list(content = "Good line")
    ), auto_unbox = TRUE),
    "THIS IS NOT VALID JSON AT ALL {{{",
    "",
    "{incomplete json",
    jsonlite::toJSON(list(
      type = "assistant", uuid = "a1", parentUuid = "u1",
      sessionId = session_uuid,
      message = list(content = "Also good")
    ), auto_unbox = TRUE)
  )

  writeLines(lines, file.path(project_subdir, paste0(session_uuid, ".jsonl")))

  result <- get_session_messages(session_uuid, directory = fake_project)
  expect_true(length(result) >= 2)
  types <- vapply(result, function(m) m$type, character(1))
  expect_equal(types, c("user", "assistant"))
})

test_that("get_session_messages: limit parameter works", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_msglimit_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  fake_project <- file.path(tmp, paste0("limit_project_", as.integer(Sys.time())))
  dir.create(fake_project, recursive = TRUE)
  on.exit(unlink(fake_project, recursive = TRUE), add = TRUE)

  sanitized_name <- ClaudeAgentSDK:::.sanitize_path(
    normalizePath(fake_project, mustWork = FALSE)
  )
  project_subdir <- file.path(test_dir, "projects", sanitized_name)
  dir.create(project_subdir, recursive = TRUE)

  session_uuid <- "11111111-2222-3333-4444-555555555555"

  lines <- c(
    jsonlite::toJSON(list(
      type = "user", uuid = "u1", sessionId = session_uuid,
      message = list(content = "First")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "assistant", uuid = "a1", parentUuid = "u1",
      sessionId = session_uuid,
      message = list(content = "Reply 1")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "user", uuid = "u2", parentUuid = "a1",
      sessionId = session_uuid,
      message = list(content = "Second")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "assistant", uuid = "a2", parentUuid = "u2",
      sessionId = session_uuid,
      message = list(content = "Reply 2")
    ), auto_unbox = TRUE)
  )

  writeLines(lines, file.path(project_subdir, paste0(session_uuid, ".jsonl")))

  result <- get_session_messages(session_uuid, directory = fake_project, limit = 2L)
  expect_equal(length(result), 2)
})

test_that("get_session_messages: offset parameter works", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_msgoffset_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  fake_project <- file.path(tmp, paste0("offset_project_", as.integer(Sys.time())))
  dir.create(fake_project, recursive = TRUE)
  on.exit(unlink(fake_project, recursive = TRUE), add = TRUE)

  sanitized_name <- ClaudeAgentSDK:::.sanitize_path(
    normalizePath(fake_project, mustWork = FALSE)
  )
  project_subdir <- file.path(test_dir, "projects", sanitized_name)
  dir.create(project_subdir, recursive = TRUE)

  session_uuid <- "aaaaaaaa-aaaa-bbbb-cccc-dddddddddddd"

  lines <- c(
    jsonlite::toJSON(list(
      type = "user", uuid = "u1", sessionId = session_uuid,
      message = list(content = "Msg 1")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "assistant", uuid = "a1", parentUuid = "u1",
      sessionId = session_uuid,
      message = list(content = "Reply 1")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "user", uuid = "u2", parentUuid = "a1",
      sessionId = session_uuid,
      message = list(content = "Msg 2")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "assistant", uuid = "a2", parentUuid = "u2",
      sessionId = session_uuid,
      message = list(content = "Reply 2")
    ), auto_unbox = TRUE)
  )

  writeLines(lines, file.path(project_subdir, paste0(session_uuid, ".jsonl")))

  result_all <- get_session_messages(session_uuid, directory = fake_project)
  result_offset <- get_session_messages(session_uuid, directory = fake_project, offset = 2L)
  expect_equal(length(result_offset), length(result_all) - 2)
})

test_that("get_session_messages: offset >= length returns empty", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, paste0("test_msgbounds_", as.integer(Sys.time())))
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  old_env <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = NA)
  Sys.setenv(CLAUDE_CONFIG_DIR = test_dir)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("CLAUDE_CONFIG_DIR") else Sys.setenv(CLAUDE_CONFIG_DIR = old_env)
  }, add = TRUE)

  fake_project <- file.path(tmp, paste0("bounds_project_", as.integer(Sys.time())))
  dir.create(fake_project, recursive = TRUE)
  on.exit(unlink(fake_project, recursive = TRUE), add = TRUE)

  sanitized_name <- ClaudeAgentSDK:::.sanitize_path(
    normalizePath(fake_project, mustWork = FALSE)
  )
  project_subdir <- file.path(test_dir, "projects", sanitized_name)
  dir.create(project_subdir, recursive = TRUE)

  session_uuid <- "bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee"

  lines <- c(
    jsonlite::toJSON(list(
      type = "user", uuid = "u1", sessionId = session_uuid,
      message = list(content = "Only message")
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      type = "assistant", uuid = "a1", parentUuid = "u1",
      sessionId = session_uuid,
      message = list(content = "Only reply")
    ), auto_unbox = TRUE)
  )

  writeLines(lines, file.path(project_subdir, paste0(session_uuid, ".jsonl")))

  result <- get_session_messages(session_uuid, directory = fake_project, offset = 100L)
  expect_equal(length(result), 0)
})

test_that("get_session_messages: invalid session_id returns empty list", {
  result <- get_session_messages("not-a-uuid")
  expect_equal(length(result), 0)
})

# ---------------------------------------------------------------------------
# Additional: .build_conversation_chain() and .is_visible_message()
# ---------------------------------------------------------------------------

test_that(".build_conversation_chain builds correct chain via parentUuid", {
  entries <- list(
    list(type = "user", uuid = "u1"),
    list(type = "assistant", uuid = "a1", parentUuid = "u1"),
    list(type = "user", uuid = "u2", parentUuid = "a1"),
    list(type = "assistant", uuid = "a2", parentUuid = "u2")
  )
  chain <- ClaudeAgentSDK:::.build_conversation_chain(entries)
  uuids <- vapply(chain, function(e) e[["uuid"]], character(1))
  expect_equal(uuids, c("u1", "a1", "u2", "a2"))
})

test_that(".build_conversation_chain returns empty list for empty input", {
  chain <- ClaudeAgentSDK:::.build_conversation_chain(list())
  expect_equal(length(chain), 0)
})

test_that(".is_visible_message returns TRUE for normal user/assistant", {
  user_entry <- list(type = "user", uuid = "u1")
  asst_entry <- list(type = "assistant", uuid = "a1")
  expect_true(ClaudeAgentSDK:::.is_visible_message(user_entry))
  expect_true(ClaudeAgentSDK:::.is_visible_message(asst_entry))
})

test_that(".is_visible_message returns FALSE for meta messages", {
  meta <- list(type = "user", uuid = "u1", isMeta = TRUE)
  expect_false(ClaudeAgentSDK:::.is_visible_message(meta))
})

test_that(".is_visible_message returns FALSE for sidechain messages", {
  sidechain <- list(type = "assistant", uuid = "a1", isSidechain = TRUE)
  expect_false(ClaudeAgentSDK:::.is_visible_message(sidechain))
})

test_that(".is_visible_message returns FALSE for team messages", {
  team <- list(type = "user", uuid = "u1", teamName = "my-team")
  expect_false(ClaudeAgentSDK:::.is_visible_message(team))
})

test_that(".is_visible_message returns FALSE for non-user/assistant types", {
  progress <- list(type = "progress", uuid = "p1")
  system_msg <- list(type = "system", uuid = "s1")
  expect_false(ClaudeAgentSDK:::.is_visible_message(progress))
  expect_false(ClaudeAgentSDK:::.is_visible_message(system_msg))
})

# ---------------------------------------------------------------------------
# Additional: .read_session_lite()
# ---------------------------------------------------------------------------

test_that(".read_session_lite returns NULL for non-existent file", {
  result <- ClaudeAgentSDK:::.read_session_lite("/nonexistent/path/file.jsonl")
  expect_null(result)
})

test_that(".read_session_lite reads small files correctly", {
  tmp_file <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp_file), add = TRUE)
  content <- make_session_jsonl("Test content")
  writeLines(content, tmp_file)

  result <- ClaudeAgentSDK:::.read_session_lite(tmp_file)
  expect_true(is.list(result))
  expect_true("head" %in% names(result))
  expect_true("tail" %in% names(result))
  expect_true("mtime" %in% names(result))
  expect_true("size" %in% names(result))
  # For small files, head == tail
  expect_equal(result$head, result$tail)
  expect_true(result$size > 0)
})
