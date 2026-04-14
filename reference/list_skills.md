# List available Claude Code skills

Scans `~/.claude/skills/` and the per-project `.claude/skills/`
directory for `*.md` skill files.

## Usage

``` r
list_skills(cwd = getwd())
```

## Arguments

- cwd:

  Character. Project directory to scan for local skills (default current
  working directory).

## Value

Character vector of skill names (file stem, no extension).

## Examples

``` r
skills <- list_skills()
length(skills)  # 0 if no skills installed
#> [1] 0
```
