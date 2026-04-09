# Tests for rate_limit_event parsing — mirrors Python test_rate_limit_event_repro.py

test_that("rate_limit_event with allowed_warning is parsed as RateLimitEvent", {
  json <- paste0(
    '{"type":"rate_limit_event","uuid":"u1","session_id":"s1",',
    '"rate_limit_info":{',
    '"status":"allowed_warning",',
    '"resets_at":1700000000000,',
    '"rateLimitType":"five_hour",',
    '"utilization":0.85,',
    '"someNewField":"extra"',
    '}}'
  )
  msg <- parse_message(json)
  expect_s3_class(msg, "RateLimitEvent")
  expect_equal(msg$uuid, "u1")
  expect_equal(msg$session_id, "s1")

  info <- msg$rate_limit_info
  expect_s3_class(info, "RateLimitInfo")
  expect_equal(info$status, "allowed_warning")
  expect_equal(info$resets_at, 1700000000000)
  expect_equal(info$rate_limit_type, "five_hour")
  expect_equal(info$utilization, 0.85)
})

test_that("rate_limit_event with rejected status parses overage fields", {
  json <- paste0(
    '{"type":"rate_limit_event","uuid":"u2","session_id":"s2",',
    '"rate_limit_info":{',
    '"status":"rejected",',
    '"rateLimitType":"daily",',
    '"overage_status":"hard_capped",',
    '"overage_disabled_reason":"billing limit"',
    '}}'
  )
  msg  <- parse_message(json)
  info <- msg$rate_limit_info
  expect_equal(info$status, "rejected")
  expect_equal(info$overage_status, "hard_capped")
  expect_equal(info$overage_disabled_reason, "billing limit")
})

test_that("rate_limit_event with minimal fields parses correctly", {
  json <- '{"type":"rate_limit_event","uuid":"u3","session_id":"s3","rate_limit_info":{"status":"allowed"}}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "RateLimitEvent")
  info <- msg$rate_limit_info
  expect_equal(info$status, "allowed")
  expect_null(info$resets_at)
  expect_null(info$utilization)
})

test_that("unknown message type returns NULL (forward compat)", {
  json <- '{"type":"totally_new_type_2026","data":"x"}'
  msg  <- parse_message(json)
  expect_null(msg)
})

test_that("known message types still parse normally alongside rate_limit", {
  json <- '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"hi"}],"model":"m"}}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "AssistantMessage")
})
