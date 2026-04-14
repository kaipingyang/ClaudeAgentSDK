# Create ClaudeAgentOptions

Constructs an options object controlling every aspect of a Claude Code
session. Mirrors the Python SDK's `ClaudeAgentOptions` dataclass
field-for-field.

## Usage

``` r
ClaudeAgentOptions(
  tools = NULL,
  allowed_tools = character(),
  system_prompt = NULL,
  mcp_servers = list(),
  permission_mode = NULL,
  continue_conversation = FALSE,
  resume = NULL,
  session_id = NULL,
  max_turns = NULL,
  max_budget_usd = NULL,
  disallowed_tools = character(),
  model = NULL,
  fallback_model = NULL,
  betas = character(),
  permission_prompt_tool_name = NULL,
  cwd = NULL,
  cli_path = NULL,
  settings = NULL,
  add_dirs = list(),
  env = list(),
  extra_args = list(),
  max_buffer_size = NULL,
  stderr = NULL,
  can_use_tool = NULL,
  hooks = NULL,
  user = NULL,
  include_partial_messages = FALSE,
  fork_session = FALSE,
  agents = NULL,
  setting_sources = NULL,
  sandbox = NULL,
  plugins = list(),
  max_thinking_tokens = NULL,
  thinking = NULL,
  effort = NULL,
  output_format = NULL,
  enable_file_checkpointing = FALSE,
  task_budget = NULL
)
```

## Arguments

- tools:

  Character vector, named list (`type="preset"`), or NULL. Base set of
  tools available to Claude. Passing
  `list(type="preset", preset="claude_code")` maps to `--tools default`.

- allowed_tools:

  Character vector. Additional tools to allow beyond the base set
  (`--allowedTools`).

- system_prompt:

  Character, named list (`type="preset"` / `type="file"`), or NULL.
  System prompt text or configuration.

- mcp_servers:

  Named list of MCP server configs, or character path to an MCP config
  file.

- permission_mode:

  Character or NULL. One of `"default"`, `"acceptEdits"`,
  `"bypassPermissions"`, `"plan"`, `"dontAsk"`, `"auto"`.

- continue_conversation:

  Logical. Continue the most recent session (`--continue`).

- resume:

  Character or NULL. Resume a specific session ID (`--resume`).

- session_id:

  Character or NULL. Explicit session ID to use (`--session-id`).

- max_turns:

  Integer or NULL. Maximum conversation turns (`--max-turns`).

- max_budget_usd:

  Numeric or NULL. Budget cap in USD (`--max-budget-usd`).

- disallowed_tools:

  Character vector. Tools to block (`--disallowedTools`).

- model:

  Character or NULL. Model ID (`--model`).

- fallback_model:

  Character or NULL. Fallback model ID (`--fallback-model`).

- betas:

  Character vector. SDK beta feature flags (`--betas`).

- permission_prompt_tool_name:

  Character or NULL. Tool name used for the permission prompt control
  protocol (`--permission-prompt-tool`).

- cwd:

  Character or NULL. Working directory for the Claude process.

- cli_path:

  Character or NULL. Explicit path to the `claude` binary.

- settings:

  Character or NULL. Path to a settings JSON file, or a raw JSON string
  (`--settings`).

- add_dirs:

  List of character paths. Additional directories to add (`--add-dir`).

- env:

  Named list of character strings. Extra environment variables for the
  subprocess.

- extra_args:

  Named list. Arbitrary extra CLI flags. Each name becomes `--<name>`;
  the value is the flag value (`NULL` for boolean flags).

- max_buffer_size:

  Integer or NULL. Maximum bytes to buffer from CLI stdout before
  raising an error (default 1 MB).

- stderr:

  Function(line) or NULL. Callback receiving each stderr line.

- can_use_tool:

  Function or NULL. Permission callback with signature
  `function(tool_name, tool_input, context)` returning a
  `PermissionResultAllow` or `PermissionResultDeny`.

- hooks:

  Named list of HookMatcher lists keyed by hook event name.

- user:

  Character or NULL. OS user to run the subprocess as.

- include_partial_messages:

  Logical. Emit partial streaming messages
  (`--include-partial-messages`).

- fork_session:

  Logical. Fork resumed session to a new session ID (`--fork-session`).

- agents:

  Named list of agent definitions.

- setting_sources:

  Character vector or NULL. Setting sources to load
  (`--setting-sources`).

- sandbox:

  List or NULL. Sandbox settings dict.

- plugins:

  List of plugin configs (`type="local"`, `path=...`).

- max_thinking_tokens:

  Integer or NULL. **Deprecated**; use `thinking`.

- thinking:

  Named list or NULL. Thinking config (`list(type="adaptive")`,
  `list(type="enabled", budget_tokens=N)`, `list(type="disabled")`).

- effort:

  Character or NULL. Thinking depth: `"low"`, `"medium"`, `"high"`,
  `"max"`.

- output_format:

  Named list or NULL. Structured output format, e.g.
  `list(type="json_schema", schema=list(...))`.

- enable_file_checkpointing:

  Logical. Track file changes for rewind support.

- task_budget:

  Named list or NULL. API-side task budget, e.g. `list(total = 10000L)`.

## Value

Object of class `ClaudeAgentOptions`.
