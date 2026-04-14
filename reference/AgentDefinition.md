# Create an AgentDefinition

Defines a custom sub-agent that Claude Code can delegate tasks to.
Mirrors Python's `AgentDefinition` dataclass in `types.py`.

## Usage

``` r
AgentDefinition(
  description,
  prompt = NULL,
  tools = NULL,
  disallowed_tools = NULL,
  model = NULL,
  skills = NULL,
  memory = NULL,
  mcp_servers = NULL,
  initial_prompt = NULL,
  max_turns = NULL,
  background = NULL,
  effort = NULL,
  permission_mode = NULL
)
```

## Arguments

- description:

  Character. Short description of what this agent does.

- prompt:

  Character or NULL. System prompt for the agent.

- tools:

  Character vector or NULL. Tools the agent can use.

- disallowed_tools:

  Character vector or NULL. Tools the agent cannot use.

- model:

  Character or NULL. Model ID for the agent.

- skills:

  Character vector or NULL. Additional skills for the agent.

- memory:

  Character or NULL. Memory scope: `"user"`, `"project"`, or `"local"`.

- mcp_servers:

  List or NULL. MCP server configurations.

- initial_prompt:

  Character or NULL. Initial prompt for the agent.

- max_turns:

  Integer or NULL. Maximum turns for the agent.

- background:

  Logical or NULL. Whether agent runs in background.

- effort:

  Character or integer or NULL. Effort level: `"low"`, `"medium"`,
  `"high"`, `"max"`, or an integer.

- permission_mode:

  Character or NULL. Permission mode for the agent.

## Value

Object of class `AgentDefinition`.

## Examples

``` r
agent <- AgentDefinition(
  description = "A code review assistant",
  prompt      = "Review code for correctness and style.",
  tools       = c("Read", "Bash"),
  max_turns   = 10L
)
agent$description
#> [1] "A code review assistant"
```
