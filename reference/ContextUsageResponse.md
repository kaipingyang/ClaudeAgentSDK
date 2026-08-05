# Create a ContextUsageResponse

Create a ContextUsageResponse

## Usage

``` r
ContextUsageResponse(
  categories,
  total_tokens,
  max_tokens = NULL,
  raw_max_tokens = NULL,
  percentage = NULL,
  model = NULL,
  is_auto_compact_enabled = NULL,
  memory_files = NULL,
  mcp_tools = NULL,
  agents = NULL,
  grid_rows = NULL,
  auto_compact_threshold = NULL,
  deferred_builtin_tools = NULL,
  system_tools = NULL,
  system_prompt_sections = NULL,
  slash_commands = NULL,
  skills = NULL,
  message_breakdown = NULL,
  api_usage = NULL
)
```

## Arguments

- categories:

  List of `ContextUsageCategory`.

- total_tokens:

  Integer. Total tokens currently in the context window.

- max_tokens:

  Integer or NULL. Effective maximum tokens (may be reduced by the
  autocompact buffer).

- raw_max_tokens:

  Integer or NULL. Raw model context window size.

- percentage:

  Numeric or NULL. Percentage of context window used (0-100).

- model:

  Character or NULL. Model the usage is calculated for.

- is_auto_compact_enabled:

  Logical or NULL. Whether autocompact is enabled.

- memory_files:

  List or NULL. Loaded CLAUDE.md/memory files with token counts.

- mcp_tools:

  List or NULL. MCP tools with name/serverName/tokens/isLoaded.

- agents:

  List or NULL. Agent definitions with agentType/source/token counts.

- grid_rows:

  List or NULL. Visual grid representation used by the CLI.

- auto_compact_threshold:

  Integer or NULL. Token threshold that triggers autocompact.

- deferred_builtin_tools:

  List or NULL. Built-in tools deferred from the initial tool list.

- system_tools:

  List or NULL. System (built-in) tools with token counts.

- system_prompt_sections:

  List or NULL. System-prompt sections with token counts.

- slash_commands:

  List or NULL. Slash commands with token counts.

- skills:

  List or NULL. Skills with token counts.

- message_breakdown:

  List or NULL. Per-message token breakdown.

- api_usage:

  List or NULL. Raw API usage figures.

## Value

Object of class `ContextUsageResponse`.

## Examples

``` r
cats <- list(ContextUsageCategory("user", 1024L, "#4e79a7"))
resp <- ContextUsageResponse(cats, total_tokens = 1024L)
resp$totalTokens
#> [1] 1024
```
