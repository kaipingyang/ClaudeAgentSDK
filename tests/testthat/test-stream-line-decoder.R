test_that("stream line decoder retains partial input as independent chunks", {
  decoder <- ClaudeAgentSDK:::.new_stream_line_decoder()
  chunks <- rep(strrep("x", 1024L), 128L)

  for (chunk in chunks) {
    expect_identical(decoder$feed(chunk), character())
  }

  expect_identical(decoder$buffered_chunks(), 128L)
  expect_identical(decoder$buffered_chars(), 128L * 1024L)

  expect_identical(decoder$feed("\n"), paste0(chunks, collapse = ""))
  expect_identical(decoder$buffered_chunks(), 0L)
  expect_identical(decoder$buffered_chars(), 0L)
})

test_that("stream line decoder preserves complete-line order and trailing partial", {
  decoder <- ClaudeAgentSDK:::.new_stream_line_decoder()

  expect_identical(decoder$feed("first"), character())
  expect_identical(decoder$feed(" line\nsecond\nthird"), c("first line", "second"))
  expect_identical(decoder$buffered_chars(), 5L)
  expect_identical(decoder$feed(" line\n\n"), c("third line", ""))
  expect_identical(decoder$buffered_chars(), 0L)
})

test_that("deferred frames remain separate from an incomplete stream frame", {
  decoder <- ClaudeAgentSDK:::.new_stream_line_decoder()
  expect_identical(decoder$feed("partial"), character())

  deferred <- c('{"type":"user"}', '{"type":"assistant"}')
  decoder$defer(deferred)
  expect_identical(
    decoder$feed(" frame\n"),
    c(deferred, "partial frame")
  )
  expect_identical(decoder$buffered_chars(), 0L)
})
