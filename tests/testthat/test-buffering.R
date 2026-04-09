# Tests for line buffering / split_lines_with_buffer — mirrors Python test_subprocess_buffering.py
# R uses split_lines_with_buffer() for JSON line parsing from subprocess stdout.

test_that("multiple JSON objects on separate lines are split correctly", {
  res <- split_lines_with_buffer("", '{"type":"user"}\n{"type":"result"}\n')
  expect_equal(res$complete_lines, c('{"type":"user"}', '{"type":"result"}'))
  expect_equal(res$remaining, "")
})

test_that("JSON with no trailing newline buffers correctly", {
  res <- split_lines_with_buffer("", '{"type":"user"}')
  expect_equal(res$complete_lines, character(0))
  expect_equal(res$remaining, '{"type":"user"}')
})

test_that("multiple consecutive newlines between objects are handled", {
  res <- split_lines_with_buffer("", '{"a":1}\n\n\n{"b":2}\n')
  # empty lines are included but parse_message will handle them
  expect_true('{"a":1}' %in% res$complete_lines)
  expect_true('{"b":2}' %in% res$complete_lines)
})

test_that("split JSON across multiple reads is reassembled", {
  # Simulate a JSON object split across two reads
  res1 <- split_lines_with_buffer("", '{"type":"us')
  expect_equal(res1$complete_lines, character(0))
  expect_equal(res1$remaining, '{"type":"us')

  res2 <- split_lines_with_buffer(res1$remaining, 'er"}\n')
  expect_equal(res2$complete_lines, '{"type":"user"}')
  expect_equal(res2$remaining, "")
})

test_that("large minified JSON split into chunks reassembles", {
  # Build a large JSON string and split into small chunks
  big_val <- paste(rep("x", 1000), collapse = "")
  json_line <- paste0('{"type":"user","data":"', big_val, '"}\n')

  buf <- ""
  all_lines <- character(0)
  chunk_size <- 100L
  for (i in seq(1, nchar(json_line), by = chunk_size)) {
    chunk <- substr(json_line, i, min(i + chunk_size - 1L, nchar(json_line)))
    res <- split_lines_with_buffer(buf, chunk)
    all_lines <- c(all_lines, res$complete_lines)
    buf <- res$remaining
  }
  expect_equal(length(all_lines), 1L)
  parsed <- jsonlite::fromJSON(all_lines[[1L]], simplifyVector = FALSE)
  expect_equal(parsed$type, "user")
  expect_equal(nchar(parsed$data), 1000L)
})

test_that("mixed complete and split JSON are parsed correctly", {
  # First chunk: one complete + one partial
  res1 <- split_lines_with_buffer("", '{"a":1}\n{"b":')
  expect_equal(res1$complete_lines, '{"a":1}')
  expect_equal(res1$remaining, '{"b":')

  # Second chunk: complete the partial + one more complete
  res2 <- split_lines_with_buffer(res1$remaining, '2}\n{"c":3}\n')
  expect_equal(res2$complete_lines, c('{"b":2}', '{"c":3}'))
  expect_equal(res2$remaining, "")
})

test_that("non-JSON debug lines are preserved in split output", {
  # split_lines_with_buffer splits on newlines, doesn't validate JSON
  # The transport layer's receive_messages() handles skipping non-JSON
  res <- split_lines_with_buffer("", '[SandboxDebug] init\n{"type":"user"}\n')
  expect_equal(res$complete_lines, c("[SandboxDebug] init", '{"type":"user"}'))
})

test_that("empty input returns empty", {
  res <- split_lines_with_buffer("", "")
  expect_equal(res$complete_lines, character(0))
  expect_equal(res$remaining, "")
})

test_that("buffer-only input with newline completes", {
  res <- split_lines_with_buffer("buffered", "\n")
  expect_equal(res$complete_lines, "buffered")
  expect_equal(res$remaining, "")
})
