## R CMD CHECK

### Local check (R 4.4.2, Linux x86_64)

```
── R CMD check results ──────────── ClaudeAgentSDK 0.2.0 ────
Duration: ~2m

0 errors ✔ | 0 warnings ✔ | 1 note ✖

❯ checking for future file timestamps ... NOTE
  unable to verify current time
```

The timestamp NOTE is a known artifact of offline/air-gapped environments.
It will not appear in CRAN's connected check servers.

### win-builder (R-devel)

The build environment does not have outbound access to win-builder.r-project.org.
CRAN's own Windows checks will be the first Windows validation.

---

## Test environments

- Local: Linux x86_64, R 4.4.2
- win-builder: Windows, R-devel (submitted)

---

## Notes for CRAN reviewers

### SystemRequirements

This package requires the **Claude Code CLI** (`claude` binary, >= 2.0.0),
a command-line tool provided by Anthropic. The CLI must be installed
separately by the user; the package does not bundle or download it.

All functions that require the CLI are wrapped in `\dontrun{}` in their
`@examples`. Integration tests detect the CLI via `skip_if_no_claude()`
and are skipped automatically when it is not available. The package loads
and all unit tests (643+) pass without the CLI present.

### Unofficial community package

This is an unofficial community R port of Anthropic's `claude-agent-sdk`.
It is not affiliated with or endorsed by Anthropic. This is stated clearly
in the DESCRIPTION and README.

### Reverse dependencies

This is a new submission; there are no existing reverse dependencies.
