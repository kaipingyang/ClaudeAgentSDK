# Session Management: List, Read, and Mutate Sessions

## Overview

Claude Code persists every conversation as a JSONL file under
`~/.claude/projects/<sanitized-cwd>/<session-uuid>.jsonl`.
ClaudeAgentSDK provides a pure-R API for reading and mutating these
files **without** requiring a live CLI connection — all functions
operate directly on disk.

| Function | Purpose |
|----|----|
| [`list_sessions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/list_sessions.md) | Discover sessions (all projects or one project) |
| [`get_session_info()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/get_session_info.md) | Metadata for a single session |
| [`get_session_messages()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/get_session_messages.md) | Full conversation transcript |
| [`rename_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/rename_session.md) | Set a human-readable title |
| [`tag_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/tag_session.md) | Attach a tag string (or clear it) |
| [`fork_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/fork_session.md) | Copy session to a new UUID |
| [`delete_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/delete_session.md) | Remove the JSONL file |

------------------------------------------------------------------------

## Listing sessions

### All projects

``` r

library(ClaudeAgentSDK)

# Returns SDKSessionInfo objects sorted by last_modified descending
sessions <- list_sessions(limit = 20L)
length(sessions)

# Every session carries: session_id, summary, last_modified, cwd,
# first_prompt, custom_title, tag, git_branch, created_at, file_size
s <- sessions[[1]]
cat(s$session_id, "|", s$summary %||% "(no summary)", "\n")
cat("cwd:", s$cwd, "\n")
cat("first_prompt:", substr(s$first_prompt %||% "", 1, 80), "\n")
```

### One project only

``` r

# Pass the project's working directory; SDK hashes it to find the
# matching ~/.claude/projects/<hash>/ sub-directory automatically.
sessions <- list_sessions(directory = getwd(), limit = 10L)
cat("Sessions in this project:", length(sessions), "\n")
```

### Pagination

``` r

page1 <- list_sessions(limit = 10L, offset = 0L)
page2 <- list_sessions(limit = 10L, offset = 10L)
```

------------------------------------------------------------------------

## Reading session metadata

``` r

session_id <- sessions[[1]]$session_id

info <- get_session_info(session_id)
if (!is.null(info)) {
  cat("summary:      ", info$summary %||% "(none)", "\n")
  cat("custom_title: ", info$custom_title %||% "(none)", "\n")
  cat("tag:          ", info$tag %||% "(none)", "\n")
  cat("last_modified:", format(info$last_modified), "\n")
}
```

------------------------------------------------------------------------

## Reading conversation history

[`get_session_messages()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/get_session_messages.md)
reconstructs the conversation chain via `parentUuid` links and returns
only visible user/assistant turns in chronological order.

``` r

msgs <- get_session_messages(session_id)
cat("Total turns:", length(msgs), "\n\n")

for (m in msgs) {
  if (m$type == "user") {
    raw  <- m$message
    text <- if (is.character(raw$content)) raw$content else "(complex content)"
    cat("User:     ", text, "\n")
  } else {
    raw <- m$message
    if (is.list(raw$content)) {
      for (blk in raw$content)
        if (identical(blk[["type"]], "text")) cat("Assistant:", blk[["text"]], "\n")
    } else if (is.character(raw$content)) {
      cat("Assistant:", raw$content, "\n")
    }
  }
}
```

Each `SessionMessage` object has:

| Field | Type | Description |
|----|----|----|
| `type` | `"user"` or `"assistant"` | Speaker role |
| `uuid` | character | Message UUID |
| `session_id` | character | Parent session UUID |
| `message` | list | Raw parsed JSON (contains `content`, `role`, etc.) |

------------------------------------------------------------------------

## Session mutations

All mutation functions operate directly on the JSONL files — **no CLI
connection required**.

### Rename (set custom title)

``` r

rename_session(session_id, title = "Sprint 12 planning")

# Verify
info <- get_session_info(session_id)
cat("custom_title:", info$custom_title, "\n")
```

Rename uses append-only semantics: a new `title` entry is appended to
the JSONL and the most-recent-wins rule applies. The original messages
are untouched.

### Tag

``` r

tag_session(session_id, tag = "reviewed")

# Clear a tag
tag_session(session_id, tag = NULL)
```

### Fork

[`fork_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/fork_session.md)
copies the transcript to a new UUID, remapping all internal UUIDs so the
fork is fully independent.

``` r

forked_id <- fork_session(
  session_id,
  title = "Experiment branch",
  # Optionally slice the transcript up to a specific message:
  # up_to_message_id = "some-uuid"
)
cat("Forked:", forked_id, "\n")
```

### Delete

``` r

# Permanently removes the .jsonl file
delete_session(forked_id)

# Confirm
stopifnot(is.null(get_session_info(forked_id)))
```

------------------------------------------------------------------------

## Shiny history browser pattern

The session listing API is designed for building read-only history UIs.
A minimal Shiny app structure:

``` r

library(shiny)
library(ClaudeAgentSDK)

ui <- fluidPage(
  sidebarLayout(
    sidebarPanel(
      selectInput("session", "Session", choices = NULL),
      actionButton("load", "Load transcript")
    ),
    mainPanel(
      uiOutput("transcript")
    )
  )
)

server <- function(input, output, session) {
  # Populate selector on startup
  observe({
    sessions <- list_sessions(limit = 50L)
    labels   <- vapply(sessions, function(s) {
      paste0(
        format(s$last_modified, "%Y-%m-%d %H:%M"),
        "  ",
        s$custom_title %||% s$summary %||% s$session_id
      )
    }, character(1))
    ids      <- vapply(sessions, function(s) s$session_id, character(1))
    updateSelectInput(session, "session", choices = setNames(ids, labels))
  })

  transcript <- eventReactive(input$load, {
    req(input$session)
    get_session_messages(input$session)
  })

  output$transcript <- renderUI({
    msgs <- transcript()
    items <- lapply(msgs, function(m) {
      if (m$type == "user") {
        raw  <- m$message
        text <- if (is.character(raw$content)) raw$content else "(complex)"
        div(class = "user-turn",   strong("User: "),      text)
      } else {
        raw <- m$message
        txt <- if (is.list(raw$content)) {
          blks <- Filter(function(b) identical(b[["type"]], "text"), raw$content)
          paste(vapply(blks, `[[`, character(1), "text"), collapse = "\n")
        } else if (is.character(raw$content)) raw$content else "(complex)"
        div(class = "asst-turn", strong("Assistant: "), txt)
      }
    })
    do.call(tagList, items)
  })
}

shinyApp(ui, server)
```

------------------------------------------------------------------------

## Notes

- **No CLI required.** All functions read/write `~/.claude/` directly.
- **`directory` parameter.** The SDK applies the same path-sanitization
  hash as the Claude Code CLI, so `directory = getwd()` always resolves
  to the correct project sub-directory.
- **Worktree support.** `list_sessions(include_worktrees = TRUE)` (the
  default) also scans git worktree paths associated with the project.
- **Mutation semantics.**
  [`rename_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/rename_session.md)
  and
  [`tag_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/tag_session.md)
  are append-only; the JSONL is never rewritten, so the originals are
  always recoverable.
  [`delete_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/delete_session.md)
  and
  [`fork_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/fork_session.md)
  are the only file-level operations.
