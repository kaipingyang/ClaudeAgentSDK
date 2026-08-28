test_that("session conversion preserves compact transcript metadata", {
  entry <- list(
    type = "user",
    uuid = "compact-1",
    sessionId = "11111111-1111-1111-1111-111111111111",
    isCompactSummary = TRUE,
    isVisibleInTranscriptOnly = TRUE,
    message = list(role = "user", content = "summary")
  )

  message <- ClaudeAgentSDK:::.to_session_message(entry)

  expect_s3_class(message, "SessionMessage")
  expect_true(message$is_compact_summary)
  expect_true(message$is_visible_in_transcript_only)
})
