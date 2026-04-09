# ClaudeAgentSDK — Developer Notes

R implementation of the Claude Agent SDK. Mirrors the Python SDK (`claude-agent-sdk-python/`) at the API level; idiomatic R internals.

## Architecture

```
R/
  types.R            # S3 constructors for all message/block/config types
  errors.R           # S3 error constructors (claude_error, cli_not_found, …)
  options.R          # ClaudeAgentOptions() — validated options object
  protocol.R         # parse_message(), build_*_json() — JSON <-> typed objects
  transport.R        # SubprocessCLITransport R6 — subprocess + control protocol
  client.R           # ClaudeSDKClient R6 — stateful multi-turn client
  query.R            # claude_run() / claude_query() — one-shot API
  sessions.R         # list_sessions(), get_session_info(), get_session_messages()
  session_mutations.R# rename_session(), tag_session(), delete_session(), fork_session()
  utils.R            # %||%, find_claude(), list_skills(), r_mcp_server(), …
```

### Key design decisions

**`SubprocessCLITransport`** spawns `claude --output-format stream-json --input-format stream-json --verbose`, reads newline-delimited JSON from stdout, and handles the bidirectional control protocol:
- `wait_for_initialize()` — sends the SDK's `initialize` control request and waits for the CLI's `control_response`. Captures the response in `private$init_result` (exposed via `get_init_result()`).
- `send_and_wait()` — synchronous polling loop for control requests that return data (mirrors Python's async `_send_control_request`). Safe only when called *between* generator iterations.
- `receive_messages()` — `coro` generator; routes `control_request` and `control_cancel_request` internally, yields all other message types.

**Agents** are sent as a named dict `{name: config}` via the `initialize` control request (not CLI args). `AgentDefinition` stores fields in snake_case; `build_agents_config()` converts to camelCase (`disallowed_tools` -> `disallowedTools`, `mcp_servers` -> `mcpServers`, etc.) during serialization.

**Session mutations** (`session_mutations.R`) operate directly on `~/.claude/projects/` JSONL files without a CLI connection. Append-only for rename/tag (most-recent-wins semantics), file deletion for delete, UUID-remapping copy for fork.

**`.simple_hash()`** uses double arithmetic with modulo (`%% 4294967296`) instead of `bitwAnd` to avoid R's 32-bit integer overflow.

**`.extract_last_json_string_field()`** uses `length(m) == 1L && m[[1L]] == -1L` instead of `identical(m, -1L)` because `gregexpr` returns `-1L` with attributes.

## Running tests

```r
devtools::test()
```

509+ tests. Integration tests require a real Claude Code CLI and skip automatically if not found.

### Test files

| File | Coverage | Needs CLI |
|------|----------|-----------|
| `test-types.R` | S3 constructors, AgentDefinition (all 13 fields), options variants | No |
| `test-errors.R` | Error constructors | No |
| `test-options.R` | ClaudeAgentOptions defaults and storage | No |
| `test-protocol.R` | parse_message (user/assistant/system/result/stream/rate_limit/control), builders, hook conversion, agents camelCase | No |
| `test-transport-build-command.R` | All CLI flag combinations (33+ scenarios) | No |
| `test-sessions-unit.R` | validate_uuid, sanitize_path, simple_hash, JSON field extraction, sort_and_slice, list_sessions with mock data, get_session_messages chain reconstruction | No |
| `test-session-mutations.R` | rename/tag/delete/fork (file I/O) | No |
| `test-client-unit.R` | Client lifecycle without CLI (disconnect/send/interrupt before connect) | No |
| `test-query.R` | claude_run, claude_query, ClaudeSDKClient lifecycle | **Yes** |
| `test-integration.R` | Full integration: get_server_info, set_permission_mode, set_model, interrupt, agents init, exclude_dynamic_sections, partial messages, StreamEvent, get_context_usage, get_mcp_status, multi-turn, stderr callback, can_use_tool, structured output, sessions list/info/messages | **Yes** |

## GitHub

Remote: `https://github.com/kaipingyang/ClaudeAgentSDK`

Push without `gh` CLI (token in `~/.Renviron`):
```bash
source ~/.Renviron
git push https://kaipingyang:${GITHUB_TOKEN}@github.com/kaipingyang/ClaudeAgentSDK.git main
```

## Known remaining gaps

- `rewind_files()` / `stop_task()` — fire-and-forget control messages, no integration test
- SDK-managed MCP servers (Python's `create_sdk_mcp_server`) — not implemented in R
- Large MCP output handling (`CLAUDE_MCP_OUTPUT_MAX_TOKENS`) — not implemented
- Plugin support — examples exist but no integration test
