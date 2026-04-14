#' @title Utility Functions
#' @description Internal helpers for binary discovery, version checking,
#'   and I/O buffer management. Mirrors helpers scattered across the Python
#'   SDK's `subprocess_cli.py` and the TypeScript SDK.
#' @name utils
#' @keywords internal
NULL

MINIMUM_CLAUDE_CODE_VERSION <- "2.0.0"

# ---------------------------------------------------------------------------
# Null-coalescing operator
# ---------------------------------------------------------------------------

#' @keywords internal
`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---------------------------------------------------------------------------
# CLI binary discovery
# ---------------------------------------------------------------------------

#' Find the Claude Code CLI binary
#'
#' Searches common install locations and the system PATH.  Raises
#' `claude_error_cli_not_found` if the binary cannot be found.
#'
#' @param cli_path Character or NULL. If non-NULL, that path is validated and
#'   returned directly (skipping the search).
#' @return Character. Absolute path to the `claude` binary.
#' @examples
#' \dontrun{
#' path <- find_claude()
#' cat("CLI found at:", path, "\n")
#'
#' # Validate a custom path
#' path2 <- find_claude("/usr/local/bin/claude")
#' }
#' @export
find_claude <- function(cli_path = NULL) {
  # User-supplied explicit path
  if (!is.null(cli_path)) {
    if (file.exists(cli_path)) return(normalizePath(cli_path, mustWork = FALSE))
    claude_cli_not_found(cli_path)
  }

  # Search PATH
  which_result <- Sys.which("claude")
  if (nzchar(which_result)) return(unname(which_result))

  # Common install locations (mirrors Python SDK)
  home <- Sys.getenv("HOME", unset = path.expand("~"))
  candidates <- c(
    file.path(home, ".npm-global", "bin", "claude"),
    "/usr/local/bin/claude",
    file.path(home, ".local", "bin", "claude"),
    file.path(home, "node_modules", ".bin", "claude"),
    file.path(home, ".yarn", "bin", "claude"),
    file.path(home, ".claude", "local", "claude")
  )

  for (p in candidates) {
    if (file.exists(p) && !dir.exists(p)) return(normalizePath(p, mustWork = FALSE))
  }

  claude_cli_not_found()
}

# ---------------------------------------------------------------------------
# Version checking
# ---------------------------------------------------------------------------

#' Check Claude Code CLI version
#'
#' Runs `claude -v`, parses the semantic version, and warns if it is below
#' the minimum required version.  Matches the Python SDK's
#' `_check_claude_version()` logic.
#'
#' @param cli_path Character. Path to the `claude` binary.
#' @param min_version Character. Minimum acceptable version string
#'   (default `"2.0.0"`).
#' @return Invisibly returns the detected version string, or `NULL` on failure.
#' @keywords internal
check_claude_version <- function(cli_path,
                                  min_version = MINIMUM_CLAUDE_CODE_VERSION) {
  result <- tryCatch(
    withCallingHandlers(
      system2(cli_path, "-v", stdout = TRUE, stderr = FALSE, timeout = 2L),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) NULL
  )
  if (is.null(result) || !length(result)) return(invisible(NULL))

  version_line <- result[[1]]
  m <- regmatches(version_line, regexpr("[0-9]+\\.[0-9]+\\.[0-9]+", version_line))
  if (!length(m)) return(invisible(NULL))

  version <- m[[1]]
  if (.compare_versions(version, min_version) < 0L) {
    warning(sprintf(
      "Claude Code version %s at %s is below the minimum required version %s. ",
      version, cli_path, min_version
    ), call. = FALSE)
  }
  invisible(version)
}

# Compare two "major.minor.patch" strings. Returns -1, 0, or 1.
.compare_versions <- function(a, b) {
  av <- as.integer(strsplit(a, "\\.")[[1]])
  bv <- as.integer(strsplit(b, "\\.")[[1]])
  for (i in seq_len(max(length(av), length(bv)))) {
    ai <- if (i <= length(av)) av[[i]] else 0L
    bi <- if (i <= length(bv)) bv[[i]] else 0L
    if (ai < bi) return(-1L)
    if (ai > bi) return(1L)
  }
  0L
}

# ---------------------------------------------------------------------------
# Skills enumeration (mirrors shinyClaudeCodeUI::list_skills)
# ---------------------------------------------------------------------------

#' List available Claude Code skills
#'
#' Scans `~/.claude/skills/` and the per-project `.claude/skills/` directory
#' for `*.md` skill files.
#'
#' @param cwd Character. Project directory to scan for local skills (default
#'   current working directory).
#' @return Character vector of skill names (file stem, no extension).
#' @examples
#' skills <- list_skills()
#' length(skills)  # 0 if no skills installed
#' @export
list_skills <- function(cwd = getwd()) {
  dirs <- c(
    file.path(Sys.getenv("HOME", path.expand("~")), ".claude", "skills"),
    file.path(cwd, ".claude", "skills")
  )
  skills <- character(0)
  for (d in dirs) {
    if (dir.exists(d)) {
      files   <- list.files(d, pattern = "\\.md$", full.names = FALSE)
      stems   <- sub("\\.md$", "", files)
      skills  <- c(skills, stems)
    }
  }
  unique(skills)
}

# ---------------------------------------------------------------------------
# MCP server helpers (mcptools integration)
# ---------------------------------------------------------------------------

#' Create an R-based MCP server entry for `mcp_servers`
#'
#' Builds a `mcp_servers` list entry that launches an R subprocess running
#' `mcptools::mcp_server()` over stdio.  Requires the `mcptools` and `ellmer`
#' packages to be installed on the system.
#'
#' ## Defining tools
#'
#' Create a standalone `.R` script that returns a `list()` of `ellmer::tool()`
#' objects (this is the value `mcptools::mcp_server()` accepts via its
#' `tools` argument):
#'
#' ```r
#' # my_tools.R
#' library(ellmer)
#' list(
#'   ellmer::tool(
#'     fun         = function(a, b) a + b,
#'     description = "Add two numbers",
#'     arguments   = list(
#'       a = ellmer::type_number("First number"),
#'       b = ellmer::type_number("Second number")
#'     )
#'   )
#' )
#' ```
#'
#' Then pass the script path:
#' ```r
#' options <- ClaudeAgentOptions(
#'   mcp_servers   = list(my_tools = r_mcp_server("my_tools.R")),
#'   allowed_tools = "mcp__my_tools__add"
#' )
#' ```
#'
#' @param tools_script Character(1) or NULL.  Path to an `.R` script that,
#'   when sourced, yields a `list()` of `ellmer::tool()` objects.  When
#'   `NULL` only the built-in session tools are exposed (controlled by
#'   `session_tools`).
#' @param session_tools Logical. Whether to expose the built-in `mcptools`
#'   session-management tools (`list_r_sessions`, `select_r_session`).
#'   Default `FALSE` for embedding use-cases.
#' @param rscript Character(1). Absolute path to the `Rscript` binary.
#'   Defaults to the binary of the *currently running* R installation
#'   (`Rscript` on Linux/macOS, `Rscript.exe` on Windows), resolved via
#'   `R.home("bin")` — always an absolute path, independent of `PATH`.
#'   Falls back to `Sys.which("Rscript")` if that path does not exist.
#'   Pass an explicit path to use a specific R installation.
#' @return A named list with `type`, `command`, and `args` suitable for use
#'   as a value inside `ClaudeAgentOptions(mcp_servers = list(...))`.
#' @examples
#' # Create an MCP server entry from a tools script
#' entry <- r_mcp_server("my_tools.R")
#' entry$type    # "stdio"
#' entry$command # path to Rscript
#'
#' # Use in ClaudeAgentOptions
#' \dontrun{
#' opts <- ClaudeAgentOptions(
#'   mcp_servers   = list(my_tools = r_mcp_server("my_tools.R")),
#'   allowed_tools = "mcp__my_tools__add"
#' )
#' }
#' @export
r_mcp_server <- function(
    tools_script  = NULL,
    session_tools = FALSE,
    rscript       = file.path(
      R.home("bin"),
      if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
    )) {
  # Validate the resolved path; fall back to PATH if R.home result is missing
  if (!file.exists(rscript)) {
    fallback <- unname(Sys.which("Rscript"))
    if (!nzchar(fallback)) {
      stop(
        "Cannot locate Rscript binary at '", rscript, "'. ",
        "Please pass rscript = '/full/path/to/Rscript' explicitly.",
        call. = FALSE
      )
    }
    warning(
      "Rscript not found at '", rscript, "'; falling back to PATH: ", fallback,
      call. = FALSE
    )
    rscript <- fallback
  }

  st_str <- if (isTRUE(session_tools)) "TRUE" else "FALSE"

  if (is.null(tools_script)) {
    rcode <- sprintf("mcptools::mcp_server(session_tools = %s)", st_str)
  } else {
    tools_script <- normalizePath(tools_script, mustWork = FALSE)
    # Escape single quotes in path (edge case on non-standard paths)
    tools_script_escaped <- gsub("'", "\\'", tools_script, fixed = TRUE)
    rcode <- sprintf(
      "mcptools::mcp_server(tools = '%s', session_tools = %s)",
      tools_script_escaped, st_str
    )
  }

  list(type = "stdio", command = rscript, args = c("-e", rcode))
}

# ---------------------------------------------------------------------------
# Buffer / line splitting
# ---------------------------------------------------------------------------

#' Split buffered output into complete lines
#'
#' Appends `new_output` to the existing `buf` and splits on newlines.
#' Returns completed lines and any remaining partial line.
#'
#' @param buf Character(1). Current carry-over buffer (may be empty string).
#' @param new_output Character(1). Raw bytes / text just read from the process.
#' @return Named list with:
#'   * `complete_lines` — Character vector of fully terminated lines (newline
#'     stripped).
#'   * `remaining` — Character(1) with any trailing partial line.
#' @keywords internal
split_lines_with_buffer <- function(buf, new_output) {
  combined <- paste0(buf, new_output)
  # Split on \n (keep trailing empty string as remaining)
  parts    <- strsplit(combined, "\n", fixed = TRUE)[[1]]
  if (length(parts) == 0L) {
    return(list(complete_lines = character(0), remaining = ""))
  }
  # Last segment is the remaining partial line (empty if input ended with \n)
  ends_with_newline <- substr(combined, nchar(combined), nchar(combined)) == "\n"
  if (ends_with_newline) {
    return(list(complete_lines = parts, remaining = ""))
  }
  list(
    complete_lines = parts[-length(parts)],
    remaining      = parts[[length(parts)]]
  )
}
