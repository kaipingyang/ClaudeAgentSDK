#' @title Session Listing and Reading
#' @description Functions to list and read Claude Code sessions stored under
#'   `~/.claude/projects/`.  Mirrors `_internal/sessions.py` from the Python
#'   SDK, including the full path-sanitization hash, head/tail metadata
#'   extraction, and conversation-chain reconstruction.
#' @name sessions
#' @keywords internal
NULL

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

.LITE_READ_BUF_SIZE   <- 65536L   # 64 KB head/tail read
.MAX_SANITIZED_LENGTH <- 200L
.UUID_RE <- "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
.TRANSCRIPT_ENTRY_TYPES <- c("user", "assistant", "progress", "system", "attachment")

# ---------------------------------------------------------------------------
# Path sanitization helpers  (mirrors Python `_sanitize_path` / `_simple_hash`)
# ---------------------------------------------------------------------------

.simple_hash <- function(s) {
  # Mirrors Python/JS signed 32-bit hash semantics:
  #   h = (h * 31 + ch) & 0xFFFFFFFF
  #   if h >= 0x80000000: h -= 0x100000000  (sign-extend)
  #   result = abs(h)
  # Use double arithmetic: %% 4294967296 == & 0xFFFFFFFF for non-negative doubles.
  h <- 0
  for (ch in utf8ToInt(s)) {
    h <- (h * 31 + ch) %% 4294967296
  }
  if (h >= 2147483648) h <- h - 4294967296   # sign-extend to signed 32-bit
  h <- abs(h)
  if (h == 0) return("0")
  digits <- c(0:9, letters[1:26])
  out <- character(0)
  n <- h
  while (n > 0) {
    out <- c(digits[[n %% 36 + 1]], out)
    n   <- n %/% 36
  }
  paste(out, collapse = "")
}

.sanitize_path <- function(name) {
  sanitized <- gsub("[^a-zA-Z0-9]", "-", name, perl = TRUE)
  if (nchar(sanitized) <= .MAX_SANITIZED_LENGTH) return(sanitized)
  h <- .simple_hash(name)
  paste0(substr(sanitized, 1L, .MAX_SANITIZED_LENGTH), "-", h)
}

# ---------------------------------------------------------------------------
# Config directory resolution
# ---------------------------------------------------------------------------

.get_claude_config_dir <- function() {
  env_dir <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = "")
  if (nzchar(env_dir)) return(normalizePath(env_dir, mustWork = FALSE))
  file.path(path.expand("~"), ".claude")
}

.get_projects_dir <- function() file.path(.get_claude_config_dir(), "projects")

.get_project_dir <- function(project_path) {
  file.path(.get_projects_dir(), .sanitize_path(project_path))
}

.canonicalize_path <- function(d) {
  tryCatch(normalizePath(d, mustWork = FALSE), error = function(e) d)
}

.find_project_dir <- function(project_path) {
  exact <- .get_project_dir(project_path)
  if (dir.exists(exact)) return(exact)
  sanitized <- .sanitize_path(project_path)
  if (nchar(sanitized) <= .MAX_SANITIZED_LENGTH) return(NULL)
  prefix        <- substr(sanitized, 1L, .MAX_SANITIZED_LENGTH)
  projects_dir  <- .get_projects_dir()
  entries <- tryCatch(list.files(projects_dir, full.names = TRUE), error = function(e) character(0))
  for (e in entries) {
    if (dir.exists(e) && startsWith(basename(e), paste0(prefix, "-"))) return(e)
  }
  NULL
}

# ---------------------------------------------------------------------------
# JSON string extraction without full parse  (avoids slow jsonlite on big files)
# ---------------------------------------------------------------------------

.extract_json_string_field <- function(text, key) {
  patterns <- c(paste0('"', key, '":"'), paste0('"', key, '": "'))
  for (pat in patterns) {
    idx <- regexpr(pat, text, fixed = TRUE)
    if (idx < 0L) next
    value_start <- idx + nchar(pat)
    sub_text    <- substr(text, value_start, min(nchar(text), value_start + 4096L))
    # scan to closing quote
    i <- 1L; buf <- character(0)
    while (i <= nchar(sub_text)) {
      ch <- substr(sub_text, i, i)
      if (ch == "\\") { buf <- c(buf, ch, substr(sub_text, i + 1L, i + 1L)); i <- i + 2L; next }
      if (ch == '"')  break
      buf <- c(buf, ch); i <- i + 1L
    }
    raw_val <- paste(buf, collapse = "")
    return(tryCatch(jsonlite::fromJSON(paste0('"', raw_val, '"')), error = function(e) raw_val))
  }
  NULL
}

.extract_last_json_string_field <- function(text, key) {
  patterns <- c(paste0('"', key, '":"'), paste0('"', key, '": "'))
  last_val <- NULL
  for (pat in patterns) {
    m <- gregexpr(pat, text, fixed = TRUE)[[1L]]
    if (length(m) == 1L && m[[1L]] == -1L) next
    for (pos in rev(m)) {
      value_start <- pos + nchar(pat)
      sub_text    <- substr(text, value_start, min(nchar(text), value_start + 4096L))
      i <- 1L; buf <- character(0)
      while (i <= nchar(sub_text)) {
        ch <- substr(sub_text, i, i)
        if (ch == "\\") { buf <- c(buf, ch, substr(sub_text, i + 1L, i + 1L)); i <- i + 2L; next }
        if (ch == '"') break
        buf <- c(buf, ch); i <- i + 1L
      }
      raw_val  <- paste(buf, collapse = "")
      last_val <- tryCatch(jsonlite::fromJSON(paste0('"', raw_val, '"')), error = function(e) raw_val)
      break
    }
  }
  last_val
}

# ---------------------------------------------------------------------------
# First-prompt extraction from head chunk
# ---------------------------------------------------------------------------

.skip_first_prompt_re <- paste0(
  "^(?:<local-command-stdout>|<session-start-hook>|<tick>|<goal>|",
  "\\[Request interrupted by user[^\\]]*\\]|",
  "\\s*<ide_opened_file>[\\s\\S]*</ide_opened_file>\\s*$|",
  "\\s*<ide_selection>[\\s\\S]*</ide_selection>\\s*$)"
)

.extract_first_prompt_from_head <- function(head) {
  lines <- strsplit(head, "\n", fixed = TRUE)[[1L]]
  command_fallback <- ""
  for (ln in lines) {
    if (!grepl('"type":"user"', ln, fixed = TRUE) &&
        !grepl('"type": "user"', ln, fixed = TRUE)) next
    if (grepl('"tool_result"', ln, fixed = TRUE))     next
    if (grepl('"isMeta":true', ln, fixed = TRUE) ||
        grepl('"isMeta": true', ln, fixed = TRUE))    next
    if (grepl('"isCompactSummary":true', ln, fixed = TRUE) ||
        grepl('"isCompactSummary": true', ln, fixed = TRUE)) next

    entry <- tryCatch(jsonlite::fromJSON(ln, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(entry) || !is.list(entry) || !identical(entry[["type"]], "user")) next

    msg <- entry[["message"]]
    if (!is.list(msg)) next
    content <- msg[["content"]]

    texts <- character(0)
    if (is.character(content)) {
      texts <- content
    } else if (is.list(content)) {
      for (blk in content) {
        if (is.list(blk) && identical(blk[["type"]], "text") && is.character(blk[["text"]])) {
          texts <- c(texts, blk[["text"]])
        }
      }
    }

    for (raw in texts) {
      result <- trimws(gsub("\n", " ", raw))
      if (!nzchar(result)) next
      cmd_m <- regmatches(result, regexpr("<command-name>(.*?)</command-name>", result, perl = TRUE))
      if (length(cmd_m) && nzchar(cmd_m)) {
        if (!nzchar(command_fallback)) {
          command_fallback <- sub(".*<command-name>(.*?)</command-name>.*", "\\1", cmd_m, perl = TRUE)
        }
        next
      }
      if (grepl(.skip_first_prompt_re, result, perl = TRUE)) next
      if (nchar(result) > 200L) result <- paste0(substr(result, 1L, 200L), "\u2026")
      return(result)
    }
  }
  if (nzchar(command_fallback)) return(command_fallback)
  ""
}

# ---------------------------------------------------------------------------
# Lite session file read  (stat + head + tail)
# ---------------------------------------------------------------------------

.read_session_lite <- function(file_path) {
  if (!file.exists(file_path)) return(NULL)
  size  <- file.info(file_path)$size
  mtime <- as.numeric(file.mtime(file_path)) * 1000

  con   <- tryCatch(file(file_path, open = "rb"), error = function(e) NULL)
  if (is.null(con)) return(NULL)
  on.exit(close(con), add = TRUE)

  head_bytes <- tryCatch(readBin(con, "raw", n = .LITE_READ_BUF_SIZE), error = function(e) raw(0))
  if (!length(head_bytes)) return(NULL)
  head <- iconv(rawToChar(head_bytes, multiple = FALSE), to = "UTF-8", sub = "")

  if (size <= .LITE_READ_BUF_SIZE) {
    tail <- head
  } else {
    tail_offset <- max(0L, size - .LITE_READ_BUF_SIZE)
    tryCatch(seek(con, tail_offset), error = function(e) NULL)
    tail_bytes  <- tryCatch(readBin(con, "raw", n = .LITE_READ_BUF_SIZE), error = function(e) raw(0))
    tail <- iconv(rawToChar(tail_bytes, multiple = FALSE), to = "UTF-8", sub = "")
  }

  list(mtime = mtime, size = size, head = head, tail = tail)
}

# ---------------------------------------------------------------------------
# Parse SDKSessionInfo from lite read
# ---------------------------------------------------------------------------

.parse_session_info_from_lite <- function(session_id, lite, project_path = NULL) {
  head  <- lite$head
  tail  <- lite$tail
  mtime <- lite$mtime
  size  <- lite$size

  # Skip sidechain sessions
  first_line <- strsplit(head, "\n", fixed = TRUE)[[1L]][[1L]]
  if (grepl('"isSidechain":true', first_line, fixed = TRUE) ||
      grepl('"isSidechain": true', first_line, fixed = TRUE)) return(NULL)

  custom_title <- .extract_last_json_string_field(tail, "customTitle") %||%
    .extract_last_json_string_field(head, "customTitle") %||%
    .extract_last_json_string_field(tail, "aiTitle") %||%
    .extract_last_json_string_field(head, "aiTitle")

  first_prompt <- .extract_first_prompt_from_head(head)
  if (!nzchar(first_prompt)) first_prompt <- NULL

  summary <- custom_title %||%
    .extract_last_json_string_field(tail, "lastPrompt") %||%
    .extract_last_json_string_field(tail, "summary") %||%
    first_prompt

  if (is.null(summary) || !nzchar(summary)) return(NULL)

  git_branch  <- .extract_last_json_string_field(tail, "gitBranch") %||%
    .extract_json_string_field(head, "gitBranch")
  session_cwd <- .extract_json_string_field(head, "cwd") %||% project_path

  tail_lines <- strsplit(tail, "\n", fixed = TRUE)[[1L]]
  tag_line   <- Find(function(ln) startsWith(ln, '{"type":"tag"'), rev(tail_lines))
  tag        <- if (!is.null(tag_line)) .extract_last_json_string_field(tag_line, "tag") else NULL

  created_at  <- NULL
  first_ts    <- .extract_json_string_field(first_line, "timestamp")
  if (!is.null(first_ts)) {
    ts_str <- sub("Z$", "+00:00", first_ts)
    created_at <- tryCatch(
      as.numeric(as.POSIXct(ts_str, format = "%Y-%m-%dT%H:%M:%OS%z")) * 1000,
      error = function(e) NULL
    )
  }

  sdk_session_info(
    session_id   = session_id,
    summary      = summary,
    last_modified = mtime,
    file_size    = size,
    custom_title = custom_title,
    first_prompt = first_prompt,
    git_branch   = git_branch,
    cwd          = session_cwd,
    tag          = tag,
    created_at   = created_at
  )
}

# ---------------------------------------------------------------------------
# Directory-level scan
# ---------------------------------------------------------------------------

.validate_uuid <- function(s) {
  if (grepl(.UUID_RE, s, ignore.case = TRUE, perl = TRUE)) s else NULL
}

.read_sessions_from_dir <- function(project_dir, project_path = NULL) {
  files <- tryCatch(
    list.files(project_dir, pattern = "\\.jsonl$", full.names = TRUE),
    error = function(e) character(0)
  )
  results <- list()
  for (f in files) {
    stem       <- tools::file_path_sans_ext(basename(f))
    session_id <- .validate_uuid(stem)
    if (is.null(session_id)) next
    lite <- .read_session_lite(f)
    if (is.null(lite)) next
    info <- .parse_session_info_from_lite(session_id, lite, project_path)
    if (!is.null(info)) results <- c(results, list(info))
  }
  results
}

.deduplicate_sessions <- function(sessions) {
  by_id <- list()
  for (s in sessions) {
    existing <- by_id[[s$session_id]]
    if (is.null(existing) || s$last_modified > existing$last_modified) {
      by_id[[s$session_id]] <- s
    }
  }
  unname(by_id)
}

.sort_and_slice <- function(sessions, limit, offset) {
  if (!length(sessions)) return(list())
  mtimes <- vapply(sessions, function(s) s$last_modified, numeric(1))
  sessions <- sessions[order(mtimes, decreasing = TRUE)]
  if (offset > 0L) {
    if (offset >= length(sessions)) return(list())
    sessions <- sessions[seq(offset + 1L, length(sessions))]
  }
  if (!is.null(limit) && limit > 0L) sessions <- sessions[seq_len(min(limit, length(sessions)))]
  sessions
}

.get_worktree_paths <- function(cwd) {
  if (is.null(cwd) || length(cwd) != 1L || !nzchar(cwd)) return(character(0))
  cwd <- .canonicalize_path(cwd)
  result <- tryCatch(
    system2("git", c("-C", shQuote(cwd), "worktree", "list", "--porcelain"),
            stdout = TRUE, stderr = FALSE, timeout = 5L),
    error = function(e) NULL, warning = function(w) NULL
  )
  if (is.null(result) || !length(result)) return(character(0))
  lines <- result[grepl("^worktree ", result)]
  sub("^worktree ", "", lines)
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

#' List Claude Code sessions
#'
#' Scans `~/.claude/projects/` (or the project-specific sub-directory) for
#' `.jsonl` session files and extracts metadata from `stat` + head/tail reads
#' — no full JSONL parsing required.
#'
#' @param directory Character or NULL. Project directory path.  When provided,
#'   only sessions for that project (and its git worktrees when
#'   `include_worktrees = TRUE`) are returned.  When `NULL`, all sessions
#'   across all projects are returned.
#' @param limit Integer or NULL. Maximum number of sessions to return.
#' @param offset Integer. Number of sessions to skip (for pagination).
#' @param include_worktrees Logical. Scan git worktrees (default `TRUE`).
#' @return List of `SDKSessionInfo` objects sorted by `last_modified`
#'   descending.
#' @examples
#' \donttest{
#' # All sessions
#' sessions <- list_sessions(limit = 5L)
#' length(sessions)
#'
#' # Sessions for a specific project
#' sessions <- list_sessions(directory = getwd(), limit = 10L)
#' if (length(sessions) > 0) cat(sessions[[1]]$session_id, "\n")
#' }
#' @export
list_sessions <- function(directory       = NULL,
                           limit           = NULL,
                           offset          = 0L,
                           include_worktrees = TRUE) {
  if (!is.null(directory)) {
    canonical <- .canonicalize_path(directory)
    worktrees <- if (include_worktrees) {
      tryCatch(.get_worktree_paths(canonical), error = function(e) character(0))
    } else {
      character(0)
    }

    all_sessions <- list()
    project_dir  <- .find_project_dir(canonical)
    if (!is.null(project_dir)) {
      all_sessions <- c(all_sessions, .read_sessions_from_dir(project_dir, canonical))
    }
    seen_dirs <- character(0)
    if (!is.null(project_dir)) seen_dirs <- basename(project_dir)

    for (wt in worktrees) {
      if (wt == canonical) next
      wd  <- .find_project_dir(wt)
      if (is.null(wd)) next
      bn  <- basename(wd)
      if (bn %in% seen_dirs) next
      seen_dirs    <- c(seen_dirs, bn)
      all_sessions <- c(all_sessions, .read_sessions_from_dir(wd, wt))
    }

    deduped <- .deduplicate_sessions(all_sessions)
    return(.sort_and_slice(deduped, limit, offset))
  }

  # No directory: scan all project dirs
  projects_dir <- .get_projects_dir()
  dirs         <- tryCatch(
    list.dirs(projects_dir, full.names = TRUE, recursive = FALSE),
    error = function(e) character(0)
  )
  all_sessions <- list()
  for (d in dirs) {
    all_sessions <- c(all_sessions, .read_sessions_from_dir(d))
  }
  deduped <- .deduplicate_sessions(all_sessions)
  .sort_and_slice(deduped, limit, offset)
}

#' Get metadata for a single session
#'
#' @param session_id Character. UUID of the session.
#' @param directory Character or NULL. Project directory; when `NULL` all
#'   project directories are searched.
#' @return An `SDKSessionInfo` object, or `NULL` if not found.
#' @examples
#' \donttest{
#' sessions <- list_sessions(limit = 1L)
#' if (length(sessions) > 0) {
#'   info <- get_session_info(sessions[[1]]$session_id)
#'   info$session_id
#' }
#' }
#' @export
get_session_info <- function(session_id, directory = NULL) {
  uuid <- .validate_uuid(session_id)
  if (is.null(uuid)) return(NULL)
  file_name <- paste0(uuid, ".jsonl")

  if (!is.null(directory)) {
    canonical   <- .canonicalize_path(directory)
    project_dir <- .find_project_dir(canonical)
    if (!is.null(project_dir)) {
      lite <- .read_session_lite(file.path(project_dir, file_name))
      if (!is.null(lite)) return(.parse_session_info_from_lite(uuid, lite, canonical))
    }
    # Try worktrees
    worktrees <- tryCatch(.get_worktree_paths(canonical), error = function(e) character(0))
    for (wt in worktrees) {
      if (wt == canonical) next
      wd <- .find_project_dir(wt)
      if (is.null(wd)) next
      lite <- .read_session_lite(file.path(wd, file_name))
      if (!is.null(lite)) return(.parse_session_info_from_lite(uuid, lite, wt))
    }
    return(NULL)
  }

  # Search all projects
  projects_dir <- .get_projects_dir()
  dirs <- tryCatch(list.dirs(projects_dir, full.names = TRUE, recursive = FALSE),
                   error = function(e) character(0))
  for (d in dirs) {
    lite <- .read_session_lite(file.path(d, file_name))
    if (!is.null(lite)) return(.parse_session_info_from_lite(uuid, lite))
  }
  NULL
}

#' Get conversation messages from a session
#'
#' Reads the full JSONL transcript, reconstructs the conversation chain via
#' `parentUuid` links, and returns `user`/`assistant` messages in
#' chronological order.
#'
#' @param session_id Character. UUID of the session.
#' @param directory Character or NULL. Project directory.
#' @param limit Integer or NULL. Maximum messages to return.
#' @param offset Integer. Messages to skip.
#' @return List of `SessionMessage` objects.
#' @examples
#' \donttest{
#' sessions <- list_sessions(limit = 1L)
#' if (length(sessions) > 0) {
#'   msgs <- get_session_messages(sessions[[1]]$session_id, limit = 5L)
#'   length(msgs)
#' }
#' }
#' @export
get_session_messages <- function(session_id,
                                  directory = NULL,
                                  limit     = NULL,
                                  offset    = 0L) {
  uuid <- .validate_uuid(session_id)
  if (is.null(uuid)) return(list())

  content <- .read_session_file(uuid, directory)
  if (is.null(content) || !nzchar(content)) return(list())

  entries <- .parse_transcript_entries(content)
  chain   <- .build_conversation_chain(entries)
  visible <- Filter(.is_visible_message, chain)
  messages <- lapply(visible, .to_session_message)

  if (offset > 0L) {
    if (offset >= length(messages)) return(list())
    messages <- messages[seq(offset + 1L, length(messages))]
  }
  if (!is.null(limit) && limit > 0L) {
    messages <- messages[seq_len(min(limit, length(messages)))]
  }
  messages
}

# ---------------------------------------------------------------------------
# Session file reading
# ---------------------------------------------------------------------------

.read_session_file <- function(session_id, directory) {
  file_name <- paste0(session_id, ".jsonl")

  if (!is.null(directory)) {
    canonical   <- .canonicalize_path(directory)
    project_dir <- .find_project_dir(canonical)
    if (!is.null(project_dir)) {
      path    <- file.path(project_dir, file_name)
      if (file.exists(path)) {
        content <- tryCatch(readLines(path, warn = FALSE), error = function(e) NULL)
        if (!is.null(content)) return(paste(content, collapse = "\n"))
      }
    }
    worktrees <- tryCatch(.get_worktree_paths(canonical), error = function(e) character(0))
    for (wt in worktrees) {
      if (wt == canonical) next
      wd <- .find_project_dir(wt)
      if (is.null(wd)) next
      path <- file.path(wd, file_name)
      if (file.exists(path)) {
        content <- tryCatch(readLines(path, warn = FALSE), error = function(e) NULL)
        if (!is.null(content)) return(paste(content, collapse = "\n"))
      }
    }
    return(NULL)
  }

  projects_dir <- .get_projects_dir()
  dirs <- tryCatch(list.dirs(projects_dir, full.names = TRUE, recursive = FALSE),
                   error = function(e) character(0))
  for (d in dirs) {
    path <- file.path(d, file_name)
    if (file.exists(path)) {
      content <- tryCatch(readLines(path, warn = FALSE), error = function(e) NULL)
      if (!is.null(content)) return(paste(content, collapse = "\n"))
    }
  }
  NULL
}

# ---------------------------------------------------------------------------
# Transcript parsing and chain reconstruction
# ---------------------------------------------------------------------------

.parse_transcript_entries <- function(content) {
  lines   <- strsplit(content, "\n", fixed = TRUE)[[1L]]
  entries <- list()
  for (ln in lines) {
    ln <- trimws(ln)
    if (!nzchar(ln)) next
    entry <- tryCatch(jsonlite::fromJSON(ln, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(entry) || !is.list(entry)) next
    if (entry[["type"]] %in% .TRANSCRIPT_ENTRY_TYPES && is.character(entry[["uuid"]])) {
      entries <- c(entries, list(entry))
    }
  }
  entries
}

.build_conversation_chain <- function(entries) {
  if (!length(entries)) return(list())

  by_uuid    <- stats::setNames(entries, vapply(entries, function(e) e[["uuid"]], character(1)))
  entry_idx  <- stats::setNames(seq_along(entries),
                                 vapply(entries, function(e) e[["uuid"]], character(1)))

  parent_uuids <- stats::na.omit(vapply(entries, function(e) e[["parentUuid"]] %||% NA_character_, character(1)))
  terminals    <- Filter(function(e) !(e[["uuid"]] %in% parent_uuids), entries)

  # Find nearest user/assistant leaf from each terminal
  leaves <- list()
  for (terminal in terminals) {
    cur  <- terminal
    seen <- character(0)
    while (!is.null(cur)) {
      uid <- cur[["uuid"]]
      if (uid %in% seen) break
      seen <- c(seen, uid)
      if (cur[["type"]] %in% c("user", "assistant")) { leaves <- c(leaves, list(cur)); break }
      parent_id <- cur[["parentUuid"]]
      cur <- if (!is.null(parent_id)) by_uuid[[parent_id]] else NULL
    }
  }

  if (!length(leaves)) return(list())

  # Prefer non-sidechain, non-meta leaves
  main_leaves <- Filter(function(l) !isTRUE(l[["isSidechain"]]) &&
                          !isTRUE(l[["isMeta"]]) && is.null(l[["teamName"]]), leaves)
  pick_pool   <- if (length(main_leaves)) main_leaves else leaves
  leaf        <- pick_pool[[which.max(vapply(pick_pool, function(l) entry_idx[[l[["uuid"]]]] %||% -1L, integer(1)))]]

  # Walk leaf → root, then reverse
  chain <- list(); chain_seen <- character(0); cur <- leaf
  while (!is.null(cur)) {
    uid <- cur[["uuid"]]
    if (uid %in% chain_seen) break
    chain_seen <- c(chain_seen, uid)
    chain      <- c(chain, list(cur))
    parent_id  <- cur[["parentUuid"]]
    cur        <- if (!is.null(parent_id)) by_uuid[[parent_id]] else NULL
  }
  .recover_orphaned_parallel_tool_results(by_uuid, rev(chain))
}

# ---------------------------------------------------------------------------
# Parallel tool turns (Python SDK v0.2.170, mirrors the TypeScript SDK).
# The CLI writes one assistant entry per content block; N parallel tool calls
# share message.id and are chained, while each tool_result hangs off its own
# call, so the transcript forks and the parentUuid walk keeps only one branch.
# Put the missing calls/results back right after the response's last entry.
# ---------------------------------------------------------------------------
.assistant_message_id <- function(entry) {
  if (!identical(entry[["type"]], "assistant") || !is.list(entry[["message"]])) return(NULL)
  id <- entry[["message"]][["id"]]
  if (is.character(id) && length(id) == 1L && nzchar(id)) id else NULL
}

.content_block_ids <- function(entry, block_type, id_field) {
  content <- if (is.list(entry[["message"]])) entry[["message"]][["content"]] else NULL
  if (!is.list(content)) return(character())
  ids <- vapply(content, function(block) {
    if (is.list(block) && identical(block[["type"]], block_type) &&
        is.character(block[[id_field]]) && length(block[[id_field]]) == 1L) block[[id_field]]
    else NA_character_
  }, character(1))
  ids[!is.na(ids)]
}

.is_tool_result_entry <- function(entry) {
  identical(entry[["type"]], "user") && is.character(entry[["parentUuid"]]) &&
    nzchar(entry[["parentUuid"]]) && length(.content_block_ids(entry, "tool_result", "tool_use_id")) > 0L
}

.same_writer <- function(a, b) {
  isTRUE(a[["isSidechain"]]) == isTRUE(b[["isSidechain"]]) &&
    identical(a[["agentId"]], b[["agentId"]])
}

.recover_orphaned_parallel_tool_results <- function(by_uuid, chain) {
  chain_assistants <- Filter(function(e) identical(e[["type"]], "assistant"), chain)
  if (!length(chain_assistants)) return(chain)
  seen <- vapply(chain, function(e) e[["uuid"]], character(1))
  anchors <- list()
  for (entry in chain_assistants) {
    id <- .assistant_message_id(entry)
    if (!is.null(id)) anchors[[id]] <- entry
  }
  if (!length(anchors)) return(chain)

  siblings <- list()
  owner <- list()            # call id -> owning entry, or FALSE when ambiguous
  results <- list()
  for (entry in by_uuid) {
    id <- .assistant_message_id(entry)
    if (!is.null(id)) {
      siblings[[id]] <- c(siblings[[id]], list(entry))
      for (call_id in .content_block_ids(entry, "tool_use", "id")) {
        prev <- owner[[call_id]]
        if (is.null(prev)) { owner[[call_id]] <- entry; next }
        same <- is.list(prev) && identical(.assistant_message_id(prev), id)
        owner[[call_id]] <- if (same) entry else FALSE
      }
    } else if (.is_tool_result_entry(entry)) {
      results[[length(results) + 1L]] <- entry
    }
  }
  by_assistant <- list()
  add_result <- function(key, result) by_assistant[[key]] <<- c(by_assistant[[key]], list(result))
  for (result in results) {
    add_result(result[["parentUuid"]], result)
    source <- result[["sourceToolAssistantUUID"]]
    if (is.character(source) && length(source) == 1L) {
      source_entry <- by_uuid[[source]]
      if (!is.null(source_entry) && .same_writer(result, source_entry)) add_result(source, result)
    }
    for (call_id in .content_block_ids(result, "tool_result", "tool_use_id")) {
      o <- owner[[call_id]]
      if (is.list(o) && .same_writer(result, o)) add_result(o[["uuid"]], result)
    }
  }

  ts <- function(e) if (is.character(e[["timestamp"]])) e[["timestamp"]] else ""
  sort_ts <- function(xs) if (length(xs)) xs[order(vapply(xs, ts, ""), method = "radix")] else xs
  answered_on_chain <- unique(unlist(lapply(chain, .content_block_ids, "tool_result", "tool_use_id")))
  file_position <- stats::setNames(seq_along(by_uuid), names(by_uuid))
  processed <- character()
  inserts <- list()
  for (assistant in chain_assistants) {
    id <- .assistant_message_id(assistant)
    if (is.null(id) || id %in% processed) next
    processed <- c(processed, id)
    group <- siblings[[id]] %||% list(assistant)
    members <- vapply(group, function(m) m[["uuid"]], character(1))
    orphan_siblings <- Filter(function(m) !(m[["uuid"]] %in% seen), group)
    orphan_results <- list(); strays <- list(); collected <- character()
    for (member in group) {
      for (result in by_assistant[[member[["uuid"]]]] %||% list()) {
        uid <- result[["uuid"]]
        if (uid %in% seen || uid %in% collected) next
        collected <- c(collected, uid)
        if (result[["parentUuid"]] %in% members) orphan_results <- c(orphan_results, list(result))
        else strays <- c(strays, list(result))
      }
    }
    if (length(strays)) {
      answered <- unique(c(answered_on_chain,
                           unlist(lapply(orphan_results, .content_block_ids, "tool_result", "tool_use_id"))))
      strays <- strays[order(vapply(strays, function(e) file_position[[e[["uuid"]]]], numeric(1)))]
      for (result in strays) {
        call_ids <- .content_block_ids(result, "tool_result", "tool_use_id")
        open_call <- any(vapply(call_ids, function(call_id) {
          o <- owner[[call_id]]
          !(call_id %in% answered) && is.list(o) && o[["uuid"]] %in% members
        }, logical(1)))
        if (!open_call) next
        answered <- c(answered, call_ids)
        orphan_results <- c(orphan_results, list(result))
      }
    }
    if (!length(orphan_siblings) && !length(orphan_results)) next
    recovered <- c(sort_ts(orphan_siblings), sort_ts(orphan_results))
    seen <- c(seen, vapply(recovered, function(e) e[["uuid"]], character(1)))
    inserts[[anchors[[id]][["uuid"]]]] <- recovered
  }
  if (!length(inserts)) return(chain)
  out <- list()
  for (entry in chain) {
    out <- c(out, list(entry))
    extra <- inserts[[entry[["uuid"]]]]
    if (length(extra)) out <- c(out, extra)
  }
  out
}

.is_visible_message <- function(entry) {
  if (!(entry[["type"]] %in% c("user", "assistant"))) return(FALSE)
  if (isTRUE(entry[["isMeta"]]))      return(FALSE)
  if (isTRUE(entry[["isSidechain"]])) return(FALSE)
  is.null(entry[["teamName"]])
}

.to_session_message <- function(entry) {
  session_message_obj(
    type                          = if (identical(entry[["type"]], "user")) "user" else "assistant",
    uuid                          = entry[["uuid"]] %||% "",
    session_id                    = entry[["sessionId"]] %||% "",
    message                       = entry[["message"]],
    parent_tool_use_id            = NULL,
    is_compact_summary            = entry[["isCompactSummary"]],
    is_visible_in_transcript_only = entry[["isVisibleInTranscriptOnly"]]
  )
}
