# Regression: .write_all_to_process must flush the ENTIRE payload to a subprocess
# stdin, even when larger than the OS pipe buffer. A single processx write_input()
# truncates large messages (returns the unwritten remainder), which made the CLI
# hang on large text / image messages. The loop must re-feed the remainder.
test_that(".write_all_to_process writes the full payload without truncation", {
  skip_on_os("windows")
  if (!nzchar(Sys.which("wc"))) skip("wc not available")

  write_all <- ClaudeAgentSDK:::.write_all_to_process

  # `wc -c` reads ALL of stdin and prints the byte count only at EOF.
  count_via_wc <- function(payload) {
    p <- processx::process$new("wc", "-c", stdin = "|", stdout = "|")
    on.exit(try(p$kill(), silent = TRUE), add = TRUE)
    write_all(p, payload)
    close(p$get_input_connection()) # EOF so wc emits the count
    Sys.sleep(0.4)
    as.integer(trimws(paste(p$read_output_lines(), collapse = "")))
  }

  # > pipe buffer (~200KB): a single write_input() would truncate this.
  big <- paste0(paste(rep("x", 1000000L), collapse = ""), "\n")
  expect_equal(count_via_wc(big), nchar(big, type = "bytes"))

  # small payloads still work unchanged
  small <- "hello world\n"
  expect_equal(count_via_wc(small), nchar(small, type = "bytes"))
})

test_that(".write_all_to_process errors (does not hang) if the process dies mid-write", {
  skip_on_os("windows")
  write_all <- ClaudeAgentSDK:::.write_all_to_process
  p <- processx::process$new("wc", "-c", stdin = "|", stdout = "|")
  p$kill()
  Sys.sleep(0.1)
  # a large payload can't be flushed to a dead process -> should raise, not hang
  big <- paste(rep("y", 1000000L), collapse = "")
  expect_error(write_all(p, big, timeout_s = 5))
})
