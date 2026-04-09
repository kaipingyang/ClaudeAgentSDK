## mcp_tools_def.R
## Standalone tools script sourced by mcptools::mcp_server().
## Must return a list() of ellmer::tool() objects.
## Mirrors: mcp_calculator.py (Python uses in-process; R uses stdio subprocess)

library(ellmer)

list(
  # --- arithmetic tools ---
  ellmer::tool(
    fun         = function(a, b) a + b,
    description = "Add two numbers",
    arguments   = list(
      a = ellmer::type_number("First number"),
      b = ellmer::type_number("Second number")
    )
  ),

  ellmer::tool(
    fun         = function(a, b) a - b,
    description = "Subtract b from a",
    arguments   = list(
      a = ellmer::type_number("Number to subtract from"),
      b = ellmer::type_number("Number to subtract")
    )
  ),

  ellmer::tool(
    fun         = function(a, b) a * b,
    description = "Multiply two numbers",
    arguments   = list(
      a = ellmer::type_number("First number"),
      b = ellmer::type_number("Second number")
    )
  ),

  ellmer::tool(
    fun = function(a, b) {
      if (b == 0) stop("Division by zero")
      a / b
    },
    description = "Divide a by b",
    arguments   = list(
      a = ellmer::type_number("Dividend"),
      b = ellmer::type_number("Divisor (must not be zero)")
    )
  )
)
