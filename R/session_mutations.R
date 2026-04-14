#' @title Session Mutation Functions
#' @description Rename, tag, delete, and fork Claude Code sessions stored under
#'   `~/.claude/projects/`. Appends typed metadata entries to JSONL files
#'   (matching the CLI pattern). Mirrors `_internal/session_mutations.py` from
#'   the Python SDK.
#'
#'   **Concurrent writers**: if the target session is currently open in a CLI
#'   process, the CLI will absorb SDK-written entries on its next metadata
#'   re-read (tail-scan window). Safe to call from any SDK host process.
#' @name session_mutations
#' @keywords internal
NULL

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

#' Rename a session
#'
#' Appends a `custom-title` JSONL entry to the session file.
#' `list_sessions()` reads the LAST custom-title from the tail, so repeated
#' calls are safe — most recent wins.
#'
#' @param session_id Character. UUID of the session.
#' @param title Character. New title. Leading/trailing whitespace is stripped;
#'   must be non-empty after stripping.
#' @param directory Character or NULL. Project directory (same semantics as
#'   `list_sessions(directory = ...)`). When `NULL`, all project directories
#'   are searched.
#' @return Invisibly `NULL`.
#' @examples
#' \donttest{
#' sessions <- list_sessions(limit = 1L)
#' if (length(sessions) > 0) {
#'   rename_session(sessions[[1]]$session_id, "My renamed session")
#' }
#' }
#' @export
rename_session <- function(session_id, title, directory = NULL) {
  uuid <- .validate_uuid(session_id)
  if (is.null(uuid)) stop(paste0("Invalid session_id: ", session_id), call. = FALSE)
  stripped <- trimws(title)
  if (!nzchar(stripped)) stop("title must be non-empty", call. = FALSE)

  data <- paste0(
    jsonlite::toJSON(
      list(type = "custom-title", customTitle = stripped, sessionId = session_id),
      auto_unbox = TRUE
    ),
    "\n"
  )
  .append_to_session(session_id, data, directory)
  invisible(NULL)
}

#' Tag a session
#'
#' Appends a `tag` JSONL entry. Pass `NULL` to clear the tag.
#' `list_sessions()` reads the LAST tag — most recent wins.
#' Tags are Unicode-sanitized before storing.
#'
#' @param session_id Character. UUID of the session.
#' @param tag Character or NULL. Tag string, or `NULL` to clear.
#' @param directory Character or NULL. Project directory.
#' @return Invisibly `NULL`.
#' @examples
#' \donttest{
#' sessions <- list_sessions(limit = 1L)
#' if (length(sessions) > 0) {
#'   tag_session(sessions[[1]]$session_id, "important")
#'   # Clear the tag
#'   tag_session(sessions[[1]]$session_id, NULL)
#' }
#' }
#' @export
tag_session <- function(session_id, tag = NULL, directory = NULL) {
  uuid <- .validate_uuid(session_id)
  if (is.null(uuid)) stop(paste0("Invalid session_id: ", session_id), call. = FALSE)

  if (!is.null(tag)) {
    sanitized <- trimws(.sanitize_unicode_tag(tag))
    if (!nzchar(sanitized)) stop("tag must be non-empty (use NULL to clear)", call. = FALSE)
    tag <- sanitized
  }

  data <- paste0(
    jsonlite::toJSON(
      list(type = "tag", tag = if (is.null(tag)) "" else tag, sessionId = session_id),
      auto_unbox = TRUE
    ),
    "\n"
  )
  .append_to_session(session_id, data, directory)
  invisible(NULL)
}

#' Delete a session
#'
#' Removes the session's JSONL file permanently.
#'
#' @param session_id Character. UUID of the session.
#' @param directory Character or NULL. Project directory.
#' @return Invisibly `TRUE`.
#' @examples
#' \donttest{
#' # Only run this if you have a session you want to delete
#' # delete_session("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
#' }
#' @export
delete_session <- function(session_id, directory = NULL) {
  uuid <- .validate_uuid(session_id)
  if (is.null(uuid)) stop(paste0("Invalid session_id: ", session_id), call. = FALSE)

  path <- .find_session_file(session_id, directory)
  if (is.null(path)) {
    stop(paste0(
      "Session ", session_id, " not found",
      if (!is.null(directory)) paste0(" in project directory for ", directory) else ""
    ), call. = FALSE)
  }
  if (!file.remove(path)) {
    stop(paste0("Failed to delete session file: ", path), call. = FALSE)
  }
  invisible(TRUE)
}

#' Fork a session
#'
#' Copies transcript messages from the source session into a new JSONL file
#' with fresh UUIDs, preserving the `parentUuid` chain. Supports
#' `up_to_message_id` for branching from a specific point.
#'
#' @param session_id Character. UUID of the source session.
#' @param directory Character or NULL. Project directory.
#' @param up_to_message_id Character or NULL. Slice transcript up to this
#'   message UUID (inclusive). `NULL` copies the full transcript.
#' @param title Character or NULL. Custom title for the fork. If `NULL`,
#'   derives title from the original + " (fork)".
#' @return Named list with `session_id` — the UUID of the new forked session.
#' @examples
#' \donttest{
#' sessions <- list_sessions(limit = 1L)
#' if (length(sessions) > 0) {
#'   forked <- fork_session(sessions[[1]]$session_id, title = "Branch A")
#'   forked$session_id  # UUID of the new session
#' }
#' }
#' @export
fork_session <- function(session_id,
                          directory         = NULL,
                          up_to_message_id  = NULL,
                          title             = NULL) {
  uuid <- .validate_uuid(session_id)
  if (is.null(uuid)) stop(paste0("Invalid session_id: ", session_id), call. = FALSE)
  if (!is.null(up_to_message_id) && is.null(.validate_uuid(up_to_message_id))) {
    stop(paste0("Invalid up_to_message_id: ", up_to_message_id), call. = FALSE)
  }

  source_info <- .find_session_file_with_dir(session_id, directory)
  if (is.null(source_info)) {
    stop(paste0(
      "Session ", session_id, " not found",
      if (!is.null(directory)) paste0(" in project directory for ", directory) else ""
    ), call. = FALSE)
  }
  file_path   <- source_info$path
  project_dir <- source_info$project_dir

  lines_raw <- tryCatch(
    readLines(file_path, warn = FALSE),
    error = function(e) stop(paste0("Failed to read session: ", conditionMessage(e)), call. = FALSE)
  )
  if (!length(lines_raw)) stop(paste0("Session ", session_id, " has no messages"), call. = FALSE)

  parsed     <- .parse_fork_transcript(lines_raw, session_id)
  transcript <- parsed$transcript
  content_replacements <- parsed$content_replacements

  transcript <- Filter(function(e) !isTRUE(e[["isSidechain"]]), transcript)
  if (!length(transcript)) stop(paste0("Session ", session_id, " has no messages to fork"), call. = FALSE)

  # Slice at up_to_message_id
  if (!is.null(up_to_message_id)) {
    cutoff <- -1L
    for (i in seq_along(transcript)) {
      if (identical(transcript[[i]][["uuid"]], up_to_message_id)) { cutoff <- i; break }
    }
    if (cutoff == -1L) {
      stop(paste0("Message ", up_to_message_id, " not found in session ", session_id), call. = FALSE)
    }
    transcript <- transcript[seq_len(cutoff)]
  }

  # Build UUID mapping (include progress entries for parentUuid chain resolution)
  uuid_mapping <- stats::setNames(
    lapply(transcript, function(e) .generate_uuid_v4()),
    vapply(transcript, function(e) e[["uuid"]], character(1))
  )

  by_uuid <- stats::setNames(transcript, vapply(transcript, function(e) e[["uuid"]], character(1)))

  # Filter out progress entries for writing (UI-only chain links)
  writable <- Filter(function(e) !identical(e[["type"]], "progress"), transcript)
  if (!length(writable)) stop(paste0("Session ", session_id, " has no messages to fork"), call. = FALSE)

  forked_session_id <- .generate_uuid_v4()
  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3", tz = "UTC")
  now <- paste0(sub("\\.", "", now), "Z")   # ISO 8601 with milliseconds

  out_lines <- character(0)

  for (i in seq_along(writable)) {
    original <- writable[[i]]
    new_uuid <- uuid_mapping[[original[["uuid"]]]]

    # Resolve parentUuid, skipping progress ancestors
    new_parent_uuid <- NULL
    parent_id <- original[["parentUuid"]]
    while (!is.null(parent_id)) {
      parent <- by_uuid[[parent_id]]
      if (is.null(parent)) break
      if (!identical(parent[["type"]], "progress")) {
        new_parent_uuid <- uuid_mapping[[parent_id]]
        break
      }
      parent_id <- parent[["parentUuid"]]
    }

    timestamp <- if (i == length(writable)) now else (original[["timestamp"]] %||% now)

    logical_parent    <- original[["logicalParentUuid"]]
    new_logical_parent <- if (!is.null(logical_parent)) uuid_mapping[[logical_parent]] else NULL

    forked <- original
    forked[["uuid"]]               <- new_uuid
    forked[["parentUuid"]]         <- new_parent_uuid
    forked[["logicalParentUuid"]]  <- new_logical_parent
    forked[["sessionId"]]          <- forked_session_id
    forked[["timestamp"]]          <- timestamp
    forked[["isSidechain"]]        <- FALSE
    forked[["forkedFrom"]]         <- list(sessionId = session_id, messageUuid = original[["uuid"]])
    for (key in c("teamName", "agentName", "slug", "sourceToolAssistantUUID")) {
      forked[[key]] <- NULL
    }

    out_lines <- c(out_lines, jsonlite::toJSON(forked, auto_unbox = TRUE, null = "null"))
  }

  # Re-emit content replacements with the fork's sessionId
  if (length(content_replacements) > 0L) {
    out_lines <- c(out_lines, jsonlite::toJSON(
      list(type = "content-replacement", sessionId = forked_session_id,
           replacements = content_replacements),
      auto_unbox = TRUE
    ))
  }

  # Derive title
  fork_title <- if (!is.null(title) && nzchar(trimws(title))) trimws(title) else NULL
  if (is.null(fork_title)) {
    content_text <- paste(lines_raw, collapse = "\n")
    head_text <- substr(content_text, 1L, .LITE_READ_BUF_SIZE)
    tail_text <- substr(content_text, max(1L, nchar(content_text) - .LITE_READ_BUF_SIZE),
                        nchar(content_text))
    base <- (
      .extract_last_json_string_field(tail_text, "customTitle") %||%
      .extract_last_json_string_field(head_text, "customTitle") %||%
      .extract_last_json_string_field(tail_text, "aiTitle")     %||%
      .extract_last_json_string_field(head_text, "aiTitle")     %||%
      .extract_first_prompt_from_head(head_text)               %||%
      "Forked session"
    )
    fork_title <- paste0(base, " (fork)")
  }

  out_lines <- c(out_lines, jsonlite::toJSON(
    list(type = "custom-title", sessionId = forked_session_id, customTitle = fork_title),
    auto_unbox = TRUE
  ))

  # Write new session file
  fork_path <- file.path(project_dir, paste0(forked_session_id, ".jsonl"))
  tryCatch(
    writeLines(out_lines, fork_path),
    error = function(e) stop(paste0("Failed to write fork file: ", conditionMessage(e)), call. = FALSE)
  )

  list(session_id = forked_session_id)
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Find the path to a session JSONL file; returns character path or NULL.
.find_session_file <- function(session_id, directory) {
  res <- .find_session_file_with_dir(session_id, directory)
  if (is.null(res)) NULL else res$path
}

# Find session file AND its containing project directory.
# Returns list(path, project_dir) or NULL.
.find_session_file_with_dir <- function(session_id, directory) {
  file_name <- paste0(session_id, ".jsonl")

  .try_dir <- function(proj_dir) {
    path <- file.path(proj_dir, file_name)
    info <- tryCatch(file.info(path), error = function(e) NULL)
    if (!is.null(info) && !is.na(info$size) && info$size > 0L) {
      return(list(path = path, project_dir = proj_dir))
    }
    NULL
  }

  if (!is.null(directory)) {
    canonical   <- .canonicalize_path(directory)
    project_dir <- .find_project_dir(canonical)
    if (!is.null(project_dir)) {
      res <- .try_dir(project_dir)
      if (!is.null(res)) return(res)
    }
    worktrees <- tryCatch(.get_worktree_paths(canonical), error = function(e) character(0))
    for (wt in worktrees) {
      if (wt == canonical) next
      wd <- .find_project_dir(wt)
      if (is.null(wd)) next
      res <- .try_dir(wd)
      if (!is.null(res)) return(res)
    }
    return(NULL)
  }

  projects_dir <- .get_projects_dir()
  dirs <- tryCatch(list.dirs(projects_dir, full.names = TRUE, recursive = FALSE),
                   error = function(e) character(0))
  for (d in dirs) {
    res <- .try_dir(d)
    if (!is.null(res)) return(res)
  }
  NULL
}

# Append a data string to an existing session file.
.append_to_session <- function(session_id, data, directory) {
  path <- .find_session_file(session_id, directory)
  if (is.null(path)) {
    stop(paste0(
      "Session ", session_id, " not found",
      if (!is.null(directory)) paste0(" in project directory for ", directory) else ""
    ), call. = FALSE)
  }
  tryCatch(
    cat(data, file = path, append = TRUE),
    error = function(e) stop(paste0("Failed to append to session: ", conditionMessage(e)), call. = FALSE)
  )
  invisible(NULL)
}

# Parse JSONL lines into transcript entries + content-replacement records.
.FORK_TRANSCRIPT_TYPES <- c("user", "assistant", "attachment", "system", "progress")

.parse_fork_transcript <- function(lines, session_id) {
  transcript           <- list()
  content_replacements <- list()
  for (ln in lines) {
    ln <- trimws(ln)
    if (!nzchar(ln)) next
    entry <- tryCatch(jsonlite::fromJSON(ln, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(entry) || !is.list(entry)) next
    entry_type <- entry[["type"]]
    if (entry_type %in% .FORK_TRANSCRIPT_TYPES && is.character(entry[["uuid"]])) {
      transcript <- c(transcript, list(entry))
    } else if (identical(entry_type, "content-replacement") &&
               identical(entry[["sessionId"]], session_id) &&
               is.list(entry[["replacements"]])) {
      content_replacements <- c(content_replacements, entry[["replacements"]])
    }
  }
  list(transcript = transcript, content_replacements = content_replacements)
}

# Generate a UUID v4 string.
.generate_uuid_v4 <- function() {
  raw <- as.raw(sample(0:255, 16L, replace = TRUE))
  raw[[7L]] <- as.raw(bitwOr(bitwAnd(as.integer(raw[[7L]]), 0x0f), 0x40))
  raw[[9L]] <- as.raw(bitwOr(bitwAnd(as.integer(raw[[9L]]), 0x3f), 0x80))
  hex <- paste(sprintf("%02x", as.integer(raw)), collapse = "")
  paste0(substr(hex,  1L,  8L), "-",
         substr(hex,  9L, 12L), "-",
         substr(hex, 13L, 16L), "-",
         substr(hex, 17L, 20L), "-",
         substr(hex, 21L, 32L))
}

# Remove dangerous Unicode characters from a tag value.
# Mirrors Python's _sanitize_unicode() (explicit ranges, no unicodedata dependency).
.sanitize_unicode_tag <- function(value) {
  pattern <- paste0(
    "[\u200b-\u200f",   # Zero-width spaces, LTR/RTL marks
    "\u202a-\u202e",    # Directional formatting characters
    "\u2066-\u2069",    # Directional isolates
    "\ufeff",           # Byte-order mark
    "\ue000-\uf8ff]"    # BMP private-use area
  )
  gsub(pattern, "", value, perl = TRUE)
}
