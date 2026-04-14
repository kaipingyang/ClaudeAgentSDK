# Create an R-based MCP server entry for `mcp_servers`

Builds a `mcp_servers` list entry that launches an R subprocess running
`mcptools::mcp_server()` over stdio. Requires the `mcptools` and
`ellmer` packages to be installed on the system.

## Usage

``` r
r_mcp_server(
  tools_script = NULL,
  session_tools = FALSE,
  rscript = file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe"
    else "Rscript")
)
```

## Arguments

- tools_script:

  Character(1) or NULL. Path to an `.R` script that, when sourced,
  yields a [`list()`](https://rdrr.io/r/base/list.html) of
  `ellmer::tool()` objects. When `NULL` only the built-in session tools
  are exposed (controlled by `session_tools`).

- session_tools:

  Logical. Whether to expose the built-in `mcptools` session-management
  tools (`list_r_sessions`, `select_r_session`). Default `FALSE` for
  embedding use-cases.

- rscript:

  Character(1). Absolute path to the `Rscript` binary. Defaults to the
  binary of the *currently running* R installation (`Rscript` on
  Linux/macOS, `Rscript.exe` on Windows), resolved via `R.home("bin")` —
  always an absolute path, independent of `PATH`. Falls back to
  `Sys.which("Rscript")` if that path does not exist. Pass an explicit
  path to use a specific R installation.

## Value

A named list with `type`, `command`, and `args` suitable for use as a
value inside `ClaudeAgentOptions(mcp_servers = list(...))`.

## Details

### Defining tools

Create a standalone `.R` script that returns a
[`list()`](https://rdrr.io/r/base/list.html) of `ellmer::tool()` objects
(this is the value `mcptools::mcp_server()` accepts via its `tools`
argument):

    # my_tools.R
    library(ellmer)
    list(
      ellmer::tool(
        fun         = function(a, b) a + b,
        description = "Add two numbers",
        arguments   = list(
          a = ellmer::type_number("First number"),
          b = ellmer::type_number("Second number")
        )
      )
    )

Then pass the script path:

    options <- ClaudeAgentOptions(
      mcp_servers   = list(my_tools = r_mcp_server("my_tools.R")),
      allowed_tools = "mcp__my_tools__add"
    )

## Examples

``` r
# Create an MCP server entry from a tools script
entry <- r_mcp_server("my_tools.R")
entry$type    # "stdio"
#> [1] "stdio"
entry$command # path to Rscript
#> [1] "/opt/R/4.5.3/lib/R/bin/Rscript"

# Use in ClaudeAgentOptions
if (FALSE) { # \dontrun{
opts <- ClaudeAgentOptions(
  mcp_servers   = list(my_tools = r_mcp_server("my_tools.R")),
  allowed_tools = "mcp__my_tools__add"
)
} # }
```
