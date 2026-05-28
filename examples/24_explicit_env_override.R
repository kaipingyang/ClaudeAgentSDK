## Example 24 — 完全显式环境变量覆盖
##
## 目标：不依赖任何 settings.json，把所有配置通过 ClaudeAgentOptions 显式传入。
## 后端：OpenRouter + DeepSeek（via CLAUDE_SDK_CONFIG_DIR 的独立安装）。
##
## 首次使用：
##   1. 确认项目根目录 .Renviron 已填写真实 ANTHROPIC_AUTH_TOKEN
##   2. source("examples/24_explicit_env_override.R")

library(ClaudeAgentSDK)

# ── 加载项目级 .Renviron ──────────────────────────────────────────────────────
renviron_path <- file.path(
  rprojroot::find_root(rprojroot::is_r_package),
  ".Renviron"
)
if (file.exists(renviron_path)) {
  readRenviron(renviron_path)
  cat("[.Renviron 已加载]\n\n")
} else {
  cat("[.Renviron 未找到，使用已有环境变量]\n\n")
}

# ── 读取所有配置变量 ──────────────────────────────────────────────────────────
CLI_PATH   <- Sys.getenv("CLAUDE_SDK_CLI_PATH")
CONFIG_DIR <- Sys.getenv("CLAUDE_SDK_CONFIG_DIR")
AUTH_TOKEN <- Sys.getenv("ANTHROPIC_AUTH_TOKEN")
BASE_URL   <- Sys.getenv("ANTHROPIC_BASE_URL")
MODEL      <- Sys.getenv("ANTHROPIC_MODEL")
MODEL_PRO  <- Sys.getenv("ANTHROPIC_DEFAULT_SONNET_MODEL")
MODEL_OPUS <- Sys.getenv("ANTHROPIC_DEFAULT_OPUS_MODEL")
MODEL_HAIKU<- Sys.getenv("ANTHROPIC_DEFAULT_HAIKU_MODEL")
MODEL_FAST    <- Sys.getenv("ANTHROPIC_SMALL_FAST_MODEL")
CUSTOM_HEADERS <- Sys.getenv("ANTHROPIC_CUSTOM_HEADERS")

stopifnot("CLAUDE_SDK_CLI_PATH 未设置"  = nzchar(CLI_PATH))
stopifnot("CLAUDE_SDK_CONFIG_DIR 未设置" = nzchar(CONFIG_DIR))
stopifnot("ANTHROPIC_AUTH_TOKEN 未设置" = nzchar(AUTH_TOKEN))
stopifnot("ANTHROPIC_BASE_URL 未设置"   = nzchar(BASE_URL))
stopifnot("ANTHROPIC_MODEL 未设置"      = nzchar(MODEL))

cat(sprintf("CLI      : %s\n", CLI_PATH))
cat(sprintf("CONFIG   : %s\n", CONFIG_DIR))
cat(sprintf("BASE_URL : %s\n", BASE_URL))
cat(sprintf("MODEL    : %s\n", MODEL))
cat(sprintf("TOKEN    : %s...\n\n", substr(AUTH_TOKEN, 1, 12)))

# ── 完全显式 env 列表（覆盖 settings.json $env 块的所有字段）────────────────
#
# 原则：settings.json 的 env 块里有什么，这里就显式写什么。
# CLI 子进程收到的 env 来自此列表，settings.json 的 env 块即便存在也被覆盖。
# （settings.json 的非 env 字段——如 effortLevel——由下方 settings_json 覆盖）
EXPLICIT_ENV <- list(
  # 基础 Unix 环境
  HOME   = Sys.getenv("HOME"),
  PATH   = Sys.getenv("PATH"),
  TMPDIR = "/tmp",

  # Claude CLI 配置目录（sessions / projects / CLAUDE.md 写入此处）
  CLAUDE_CONFIG_DIR = CONFIG_DIR,

  # 认证（同时传两个 key 名，兼容不同 CLI 版本）
  ANTHROPIC_AUTH_TOKEN = AUTH_TOKEN,
  ANTHROPIC_API_KEY    = AUTH_TOKEN,

  # API 端点（OpenRouter）
  ANTHROPIC_BASE_URL = BASE_URL,

  # 模型别名（覆盖 settings.json 里的 Databricks 模型名）
  ANTHROPIC_MODEL                = MODEL,
  ANTHROPIC_DEFAULT_SONNET_MODEL = if (nzchar(MODEL_PRO))  MODEL_PRO  else MODEL,
  ANTHROPIC_DEFAULT_OPUS_MODEL   = if (nzchar(MODEL_OPUS)) MODEL_OPUS else MODEL,
  ANTHROPIC_DEFAULT_HAIKU_MODEL  = if (nzchar(MODEL_HAIKU))MODEL_HAIKU else MODEL,
  ANTHROPIC_SMALL_FAST_MODEL     = if (nzchar(MODEL_FAST)) MODEL_FAST else MODEL,

  # 功能开关（来自 settings.json env 块）
  ENABLE_TOOL_SEARCH              = Sys.getenv("ENABLE_TOOL_SEARCH", "true"),
  DISABLE_NON_ESSENTIAL_MODEL_CALLS = "1",

  # OpenRouter 认证：必须用 Authorization: Bearer，CLI 标准的 x-api-key 被拒
  # ANTHROPIC_CUSTOM_HEADERS 把此 header 注入每次 API 请求
  ANTHROPIC_CUSTOM_HEADERS = if (nzchar(CUSTOM_HEADERS))
    CUSTOM_HEADERS
  else
    paste0("Authorization: Bearer ", AUTH_TOKEN)
)

# ── settings JSON（覆盖 settings.json 的非 env 顶层字段）────────────────────
#
# effortLevel → 用 ClaudeAgentOptions(effort=) 代替（见下），无需放这里
# 只保留必须通过 JSON 传入的字段
EXPLICIT_SETTINGS <- jsonlite::toJSON(list(
  hasCompletedOnboarding            = TRUE,   # 跳过首次引导
  skipDangerousModePermissionPrompt = TRUE    # 跳过危险模式弹窗
), auto_unbox = TRUE)

# ── 构建完全显式 options ─────────────────────────────────────────────────────
opts <- ClaudeAgentOptions(
  cli_path  = CLI_PATH,
  env       = EXPLICIT_ENV,
  settings  = EXPLICIT_SETTINGS,
  effort    = "high",           # 对应 settings.json 的 effortLevel（SDK 原生参数）
  model     = MODEL,            # 显式传 model，不依赖 ANTHROPIC_MODEL 继承
  max_turns = 3L
)

# ── 工具函数 ──────────────────────────────────────────────────────────────────
collect_text <- function(msgs) {
  paste(Filter(nzchar, vapply(msgs, function(m) {
    if (!inherits(m, "AssistantMessage")) return("")
    paste(vapply(m$content, function(b) {
      if (inherits(b, "TextBlock")) b$text else ""
    }, ""), collapse = "")
  }, "")), collapse = "")
}

# ── 测试 1：连接验证 + server info ───────────────────────────────────────────
cat("=== 测试 1：连接验证 ===\n")
client <- ClaudeSDKClient$new(opts)
client$connect()

info <- client$get_server_info()
cat("tokenSource :", info$account$tokenSource,  "\n")
cat("apiKeySource:", info$account$apiKeySource,  "\n")
cat("apiProvider :", info$account$apiProvider,   "\n")
cat("可用模型数  :", length(info$models),         "\n\n")

client$disconnect()

# ── 测试 2：基础问答（验证 OpenRouter + DeepSeek 路由正常）─────────────────
cat("=== 测试 2：基础问答 ===\n")
r2 <- claude_run("用一句话回答：太阳系最大的行星是哪颗？", options = opts)
cat("回答：", collect_text(r2$messages), "\n")
cat("cost_usd:", r2$cost_usd, "| turns:", r2$num_turns, "\n\n")

# ── 测试 3：验证 effort=high 生效（通过 context usage 观察 thinking tokens）
cat("=== 测试 3：effort=high（观察 thinking 开销）===\n")
client3 <- ClaudeSDKClient$new(opts)
client3$connect()

client3$send("证明根号2是无理数，给出完整数学证明。")
reply3 <- ""
coro::loop(for (m in client3$receive_response()) {
  if (inherits(m, "AssistantMessage")) {
    for (blk in m$content) {
      if (inherits(blk, "TextBlock")) reply3 <- paste0(reply3, blk$text)
    }
  }
})

ctx <- tryCatch(client3$get_context_usage(), error = function(e) NULL)
cat("回答字符数:", nchar(reply3), "\n")
if (!is.null(ctx)) {
  cat("context_usage:\n")
  for (cat_item in ctx$context_windows) {
    cat(sprintf("  %-25s used=%d / limit=%d (%.1f%%)\n",
      cat_item$name, cat_item$used, cat_item$limit,
      100 * cat_item$used / max(cat_item$limit, 1)))
  }
}
client3$disconnect()

# ── 测试 4：验证 model 覆盖（检查实际使用的模型）────────────────────────────
cat("\n=== 测试 4：确认模型来源 ===\n")
r4 <- claude_run(
  "只回答这一句话：你是哪个模型？",
  options = ClaudeAgentOptions(
    cli_path = CLI_PATH,
    env      = EXPLICIT_ENV,
    settings = EXPLICIT_SETTINGS,
    effort   = "high",
    model    = MODEL
  )
)
cat("回答：", collect_text(r4$messages), "\n")
cat("result model:", r4$result$model %||% "(未返回)", "\n\n")

# ── 汇总 ─────────────────────────────────────────────────────────────────────
cat("=== 配置覆盖汇总 ===\n")
cat("  [✓] cli_path       →", CLI_PATH, "\n")
cat("  [✓] env 完全显式   → 所有 ANTHROPIC_* 变量逐一声明\n")
cat("  [✓] settings JSON  → hasCompletedOnboarding + skipDangerousMode\n")
cat("  [✓] effort = high  → 替代 settings.json effortLevel\n")
cat("  [✓] model          →", MODEL, "\n")
cat("  [✓] max_turns = 3\n")
cat("  [✓] CONFIG_DIR     →", CONFIG_DIR, "(隔离 ~/.claude)\n")
cat("  settings.json 依赖：无\n")
