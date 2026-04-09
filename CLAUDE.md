# ClaudeAgentSDK — Developer Notes

R implementation of the Claude Agent SDK. Mirrors the Python SDK (`claude-agent-sdk-python/`) at the API level; idiomatic R internals.

## Architecture

```
R/
  types.R            # S3 constructors for all message/block/config types
  errors.R           # S3 error constructors (claude_error, cli_not_found, …)
  options.R          # ClaudeAgentOptions() — validated options object
  protocol.R         # parse_message(), build_*_json() — JSON ↔ typed objects
  transport.R        # SubprocessCLITransport R6 — subprocess + control protocol
  client.R           # ClaudeSDKClient R6 — stateful multi-turn client
  query.R            # claude_run() / claude_query() — one-shot API
  sessions.R         # list_sessions(), get_session_info(), get_session_messages()
  session_mutations.R# rename_session(), tag_session(), delete_session(), fork_session()
  utils.R            # %||%, .validate_uuid(), .sanitize_path(), …
```

### Key design decisions

**`SubprocessCLITransport`** spawns `claude --output-format stream-json --input-format stream-json --verbose`, reads newline-delimited JSON from stdout, and handles the bidirectional control protocol:
- `wait_for_initialize()` — sends the SDK's `initialize` control request and waits for the CLI's `control_response`. Captures the response in `private$init_result` (exposed via `get_init_result()`).
- `send_and_wait()` — synchronous polling loop for control requests that return data (mirrors Python's async `_send_control_request`). Safe only when called *between* generator iterations.
- `receive_messages()` — `coro` generator; routes `control_request` and `control_cancel_request` internally, yields all other message types.

**`ClaudeSDKClient`** wraps the transport with a stateful API. `get_server_info()` returns the server's initialize response captured during `connect()`.

**Session mutations** (`session_mutations.R`) operate directly on `~/.claude/projects/` JSONL files without a CLI connection. Append-only for rename/tag (most-recent-wins semantics), file deletion for delete, UUID-remapping copy for fork.

**UUID v4 generation** (`R/session_mutations.R:.generate_uuid_v4`) — R has no built-in generator; implemented via `as.raw(sample(0:255, 16))` with RFC 4122 version/variant bit manipulation.

**Hook output conversion** (`convert_hook_output_for_cli`) — Python uses `continue_`/`async_` to avoid keyword conflicts; this method renames them to `continue`/`async` before sending to the CLI.

## Running tests

```r
devtools::test()
```

Tests require the `ClaudeAgentSDK` package to be installed or loaded. Integration tests (`test-integration.R`) require a real Claude Code CLI and skip automatically if not found.

### Test categories

| File | Coverage | Needs CLI |
|------|----------|-----------|
| `test-types.R` | S3 constructors | No |
| `test-errors.R` | Error constructors | No |
| `test-options.R` | ClaudeAgentOptions | No |
| `test-protocol.R` | parse_message, builders, hook conversion | No |
| `test-session-mutations.R` | rename/tag/delete/fork (file I/O) | No |
| `test-query.R` | claude_run, claude_query, ClaudeSDKClient | **Yes** |
| `test-integration.R` | get_server_info, set_permission_mode, list_sessions, get_session_messages, get_context_usage, get_mcp_status | **Yes** |

### What integration tests cover

- `get_server_info()` returns non-NULL after `connect()`
- `set_permission_mode()` / `interrupt()` don't error
- `exclude_dynamic_sections` in initialize passes through
- `agents` config in initialize passes through
- `include_partial_messages = TRUE` still yields AssistantMessage
- `get_context_usage()` / `get_mcp_status()` return real data via `send_and_wait()`
- `list_sessions()` / `get_session_info()` / `get_session_messages()` against real `~/.claude/projects/`

## GitHub

Remote: `https://github.com/kaipingyang/ClaudeAgentSDK`

Push without `gh` CLI:
```r
token <- Sys.getenv("GITHUB_TOKEN")  # set in ~/.Renviron
system2("git", c("push", paste0("https://kaipingyang:", token, "@github.com/kaipingyang/ClaudeAgentSDK.git"), "main"))
```

## Known remaining gaps

- `can_use_tool` / hook execution end-to-end — no integration test (requires a prompt that triggers a tool permission request)
- `rewind_files()` / `stop_task()` — fire-and-forget control messages, untested
- `get_session_messages(limit=)` test skips when session has only one message
