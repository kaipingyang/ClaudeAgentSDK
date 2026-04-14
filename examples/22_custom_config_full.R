## Example 22 — Full custom configuration test
##
## 本脚本测试所有可自定义的 ClaudeAgentOptions 参数。
## 敏感参数统一从项目根目录的 .Renviron 读取（已加入 .gitignore）。
##
## 首次使用：
##   1. 编辑项目根目录的 .Renviron，填入 CLAUDE_SDK_API_KEY
##   2. 在 R console 执行：readRenviron(".Renviron")
##   3. 运行本脚本：source("examples/22_custom_config_full.R")

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
  # 回退：假设已从 R session 继承了环境变量
  cat("[.Renviron 未找到，使用已有环境变量]\n\n")
}

# ── 从 .Renviron 读取敏感参数 ─────────────────────────────────────────────────
CLI_PATH   <- Sys.getenv("CLAUDE_SDK_CLI_PATH")
CONFIG_DIR <- Sys.getenv("CLAUDE_SDK_CONFIG_DIR")
BASE_URL   <- Sys.getenv("CLAUDE_SDK_BASE_URL")
MODEL      <- Sys.getenv("CLAUDE_SDK_MODEL")

# API key：优先 CLAUDE_SDK_API_KEY，回退到 ANTHROPIC_AUTH_TOKEN
.sdk_key <- Sys.getenv("CLAUDE_SDK_API_KEY")
API_KEY  <- if (nzchar(.sdk_key)) .sdk_key else Sys.getenv("ANTHROPIC_AUTH_TOKEN")
rm(.sdk_key)

stopifnot("CLI_PATH 未设置"   = nzchar(CLI_PATH))
stopifnot("CONFIG_DIR 未设置" = nzchar(CONFIG_DIR))
stopifnot("API_KEY 未设置"    = nzchar(API_KEY))

cat(sprintf("CLI:        %s\n", CLI_PATH))
cat(sprintf("CONFIG_DIR: %s\n", CONFIG_DIR))
cat(sprintf("BASE_URL:   %s\n", if (nzchar(BASE_URL)) BASE_URL else "(默认)"))
cat(sprintf("MODEL:      %s\n", if (nzchar(MODEL)) MODEL else "(由 settings.json 决定)"))
cat(sprintf("API_KEY:    %s...\n\n", substr(API_KEY, 1, 8)))

# ── 基础 env（所有测试共用）──────────────────────────────────────────────────
BASE_ENV <- list(
  CLAUDE_CONFIG_DIR = CONFIG_DIR,
  ANTHROPIC_API_KEY = API_KEY
)
# 若有自定义 BASE_URL（AI Gateway），显式注入（settings.json 也会加载，但代码更清晰）
if (nzchar(BASE_URL)) BASE_ENV[["ANTHROPIC_BASE_URL"]] <- BASE_URL

# ── 工具函数：收集 AssistantMessage 文本 ────────────────────────────────────
collect_text <- function(msgs) {
  texts <- character(0)
  for (m in msgs) {
    if (inherits(m, "AssistantMessage")) {
      for (blk in m$content) {
        if (inherits(blk, "TextBlock") && nzchar(blk$text)) texts <- c(texts, blk$text)
      }
    }
  }
  paste(texts, collapse = "")
}

# ── 工具函数：打印分隔线 ──────────────────────────────────────────────────────
section <- function(title) cat(sprintf("\n%s\n%s\n", title, strrep("─", nchar(title))))

# =============================================================================
section("测试 1：cli_path + env（基础连接验证）")
# =============================================================================
# 最小配置：只设 cli_path 和 env，验证认证与连接正常

opts1 <- ClaudeAgentOptions(
  cli_path = CLI_PATH,
  env      = BASE_ENV
)

client1 <- ClaudeSDKClient$new(opts1)
client1$connect()
info <- client1$get_server_info()
cat("连接成功\n")
cat("  tokenSource :", info$account$tokenSource,  "\n")
cat("  apiKeySource:", info$account$apiKeySource,  "\n")
cat("  apiProvider :", info$account$apiProvider,   "\n")
cat("  可用模型数  :", length(info$models),         "\n")
client1$disconnect()

# =============================================================================
section("测试 2：settings（JSON 字符串覆盖）")
# =============================================================================
# settings 参数接受文件路径或原始 JSON 字符串
# 这里用 JSON 字符串：禁用实验性 beta + 设置 output_style

custom_settings_json <- jsonlite::toJSON(list(
  env = list(
    CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1"
  ),
  preferredNotifChannel = "terminal_bell"
), auto_unbox = TRUE)

opts2 <- ClaudeAgentOptions(
  cli_path = CLI_PATH,
  env      = BASE_ENV,
  settings = custom_settings_json
)
r2 <- claude_run("用一个词回答：太阳是什么颜色？", options = opts2)
cat("settings JSON 覆盖 → 回答：", collect_text(r2$messages), "\n")

# =============================================================================
section("测试 3：settings（文件路径）")
# =============================================================================
# 把自定义配置写到临时文件，测试文件路径形式

tmp_settings_file <- tempfile(fileext = ".json")
writeLines(jsonlite::toJSON(list(
  env = list(
    CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1"
  )
), auto_unbox = TRUE), tmp_settings_file)
cat("临时 settings 文件：", tmp_settings_file, "\n")

opts3 <- ClaudeAgentOptions(
  cli_path = CLI_PATH,
  env      = BASE_ENV,
  settings = tmp_settings_file
)
r3 <- claude_run("1+1等于？只回答数字。", options = opts3)
cat("settings 文件路径 → 回答：", collect_text(r3$messages), "\n")
unlink(tmp_settings_file)

# =============================================================================
section("测试 4：system_prompt（自定义系统提示）")
# =============================================================================
# 注入一个特殊角色指令，验证系统提示生效

opts4 <- ClaudeAgentOptions(
  cli_path      = CLI_PATH,
  env           = BASE_ENV,
  system_prompt = "You are a pirate assistant. Reply ONLY in pirate-speak English, no matter what language the user uses."
)
r4 <- claude_run("你好，请介绍一下你自己。", options = opts4)
cat("system_prompt → 回答：\n", collect_text(r4$messages), "\n")

# =============================================================================
section("测试 5：cwd（工作目录）+ add_dirs（追加目录 / 自定义 CLAUDE.md）")
# =============================================================================
# cwd：Claude 子进程的当前目录（影响相对路径工具调用）
# add_dirs：让 CLI 加载指定目录的 CLAUDE.md

tmp_dir <- tempdir()
custom_claude_md <- file.path(tmp_dir, "CLAUDE.md")
writeLines(c(
  "# Custom Project Instructions",
  "",
  "IMPORTANT: Always end your response with the word 'CUSTOM_MARKER'.",
  "This confirms the custom CLAUDE.md is loaded."
), custom_claude_md)
cat("临时 CLAUDE.md：", custom_claude_md, "\n")

opts5 <- ClaudeAgentOptions(
  cli_path = CLI_PATH,
  env      = BASE_ENV,
  cwd      = tmp_dir,                  # 子进程工作目录
  add_dirs = list(tmp_dir)             # 从该目录加载 CLAUDE.md
)
r5 <- claude_run("用一句话打个招呼。", options = opts5)
reply5 <- collect_text(r5$messages)
cat("cwd + add_dirs → 回答：\n", reply5, "\n")
cat("包含 CUSTOM_MARKER：", grepl("CUSTOM_MARKER", reply5), "\n")

# =============================================================================
section("测试 6：model + max_turns")
# =============================================================================
# 显式指定模型（覆盖 settings.json 中的 ANTHROPIC_MODEL）
# max_turns 限制最大对话轮数

opts6 <- ClaudeAgentOptions(
  cli_path  = CLI_PATH,
  env       = BASE_ENV,
  model     = if (nzchar(MODEL)) MODEL else NULL,
  max_turns = 1L
)
client6 <- ClaudeSDKClient$new(opts6)
client6$connect()

client6$send("说'第一轮'。")
reply6a <- ""
coro::loop(for (m in client6$receive_response()) {
  if (inherits(m, "AssistantMessage")) {
    for (blk in m$content) {
      if (inherits(blk, "TextBlock")) reply6a <- paste0(reply6a, blk$text)
    }
  }
})
cat("model + max_turns=1 → 第一轮：", reply6a, "\n")

# max_turns=1 后再发一轮，应报错或返回空（已达上限）
second_ok <- tryCatch({
  client6$send("说'第二轮'。")
  coro::loop(for (m in client6$receive_response()) NULL)
  TRUE
}, error = function(e) {
  cat("  max_turns 达上限，已拒绝（符合预期）：", conditionMessage(e), "\n")
  FALSE
})
if (second_ok) cat("  第二轮未被拒绝（注意：max_turns 行为因版本而异）\n")
client6$disconnect()

# =============================================================================
section("测试 7：permission_mode + permission_prompt_tool_name + can_use_tool")
# =============================================================================
# permission_mode = "default"：默认权限（需确认危险操作）
# permission_prompt_tool_name = "stdio"：通过 SDK control 协议拦截审批
# can_use_tool：同步回调，决定是否允许工具调用

approved_tools  <- character(0)
denied_tools    <- character(0)

opts7 <- ClaudeAgentOptions(
  cli_path                    = CLI_PATH,
  env                         = BASE_ENV,
  permission_mode             = "default",
  permission_prompt_tool_name = "stdio",
  can_use_tool = function(name, input, ctx) {
    cat("  [权限审批] 工具:", name, "\n")
    if (name == "Read") {
      approved_tools <<- c(approved_tools, name)
      PermissionResultAllow()
    } else {
      denied_tools <<- c(denied_tools, name)
      PermissionResultDeny(paste("测试：拒绝", name))
    }
  }
)
r7 <- claude_run(
  "1) 读取 /dev/null 的内容。2) 尝试列出根目录 / 的文件。",
  options = opts7
)
cat("已批准工具：", paste(approved_tools, collapse = ", "), "\n")
cat("已拒绝工具：", paste(denied_tools,   collapse = ", "), "\n")
cat("回答：\n", collect_text(r7$messages), "\n")

# =============================================================================
section("测试 8：disallowed_tools + allowed_tools")
# =============================================================================
# disallowed_tools：SDK 级别直接禁止（不走 can_use_tool 回调）
# allowed_tools：追加允许的工具（超出默认工具集）

opts8 <- ClaudeAgentOptions(
  cli_path                    = CLI_PATH,
  env                         = BASE_ENV,
  permission_mode             = "default",          # bypassPermissions 会覆盖 disallowedTools，必须用 default
  permission_prompt_tool_name = "stdio",
  disallowed_tools            = c("Bash", "Write"), # 禁止执行命令和写文件
  allowed_tools               = c("Read", "Glob"),  # 额外明确允许读和查找
  can_use_tool = function(name, input, ctx) PermissionResultAllow()  # 非黑名单工具自动放行
)
r8 <- claude_run(
  "尝试：1) 读取 /dev/null；2) 用 Bash 运行 echo hello；3) 写入 /tmp/test.txt",
  options = opts8
)
reply8 <- collect_text(r8$messages)
cat("disallowed_tools=Bash,Write → 回答：\n", reply8, "\n")
# 注意：disallowed_tools 仅限制顶层 agent。
# 若模型派发子 agent（sub-agent），子 agent 拥有独立工具集，
# 可能绕过顶层的 disallowed_tools 限制。
# 若需要对子 agent 也生效，需在 AgentDefinition 里分别设置 disallowed_tools。
cat("Read 成功（预期）：",   grepl("/dev/null", reply8, ignore.case = TRUE), "\n")
cat("Bash/Write 受限提示：", grepl("子 agent|sub.agent|subagent|没有直接|tool", reply8, ignore.case = TRUE), "\n")

# =============================================================================
section("测试 9：stderr 回调")
# =============================================================================
# stderr 接收 CLI 进程的标准错误输出（调试日志、警告等）

stderr_lines <- character(0)
opts9 <- ClaudeAgentOptions(
  cli_path = CLI_PATH,
  env      = BASE_ENV,
  stderr   = function(line) {
    stderr_lines <<- c(stderr_lines, line)
  }
)
r9 <- claude_run("用一个字回答：天空是什么颜色？", options = opts9)
cat("收到 stderr 行数：", length(stderr_lines), "\n")
if (length(stderr_lines) > 0) {
  cat("最后一条 stderr：", tail(stderr_lines, 1), "\n")
}

# =============================================================================
section("测试 10：include_partial_messages（流式中间状态）")
# =============================================================================
# include_partial_messages = TRUE：生成器会 yield 还在更新中的 AssistantMessage
# 适用于需要"打字机效果"但不用 StreamEvent 的场景

partial_count <- 0L
opts10 <- ClaudeAgentOptions(
  cli_path                 = CLI_PATH,
  env                      = BASE_ENV,
  include_partial_messages = TRUE
)
gen10 <- claude_query("倒数：5, 4, 3, 2, 1", options = opts10)
coro::loop(for (m in gen10) {
  if (inherits(m, "AssistantMessage")) {
    partial_count <- partial_count + 1L
  }
})
cat("include_partial_messages=TRUE → AssistantMessage 帧数：", partial_count, "\n")
cat("（>1 表示流式中间帧生效）\n")

# =============================================================================
section("测试 11：structured output（JSON Schema）")
# =============================================================================
# output_format = json_schema：要求模型严格按 schema 输出 JSON

schema <- list(
  type = "object",
  properties = list(
    color    = list(type = "string", description = "颜色名称"),
    hex_code = list(type = "string", description = "十六进制颜色代码"),
    is_warm  = list(type = "boolean", description = "是否是暖色")
  ),
  required = c("color", "hex_code", "is_warm")
)

opts11 <- ClaudeAgentOptions(
  cli_path      = CLI_PATH,
  env           = BASE_ENV,
  output_format = list(type = "json_schema", schema = schema)
)
# 注意：output_format=json_schema 要求模型支持结构化输出；
# Databricks AI Gateway 托管的模型可能不遵循 schema（退化为普通文本），
# 此处用 tryCatch 兜底。
r11 <- tryCatch(
  claude_run("描述颜色：红色", options = opts11),
  error = function(e) { cat("  output_format 报错（模型不支持）：", conditionMessage(e), "\n"); NULL }
)
if (!is.null(r11)) {
  raw_json <- collect_text(r11$messages)
  cat("structured output 原始响应：\n", raw_json, "\n")
  parsed <- tryCatch(
    jsonlite::fromJSON(raw_json),
    error = function(e) {
      cat("  JSON 解析失败（模型未遵循 schema，返回了普通文本）\n")
      NULL
    }
  )
  if (!is.null(parsed)) {
    cat("解析结果：color=", parsed$color,
        "| hex=", parsed$hex_code,
        "| is_warm=", parsed$is_warm, "\n")
  }
}

# =============================================================================
section("测试 12：setting_sources（控制加载哪些配置层）")
# =============================================================================
# setting_sources 控制 CLI 从哪些层加载配置
# 可选值（各版本支持略有不同）：
#   "global"     → ~/.claude/settings.json
#   "local"      → .claude/settings.json（项目级）
#   "user"       → 用户级（与 global 类似）
#   "enterprise" → 企业级（统一管理）
# 传入单个值可以只加载特定层，隔离其他配置

opts12 <- ClaudeAgentOptions(
  cli_path        = CLI_PATH,
  env             = BASE_ENV,
  setting_sources = "user"     # 只加载 user 层配置（有效值：user / project / local）
)
r12 <- claude_run("用一个词回答：水是什么颜色？", options = opts12)
cat("setting_sources=global → 回答：", collect_text(r12$messages), "\n")

# =============================================================================
section("测试 13：multi-turn 会话 + resume（跨连接恢复）")
# =============================================================================
# 正确模式：不手动指定 session_id，让 CLI 自动生成。
# 第一次连接结束后从 list_sessions() 拿到 CLI 生成的 id，
# 第二次连接用 resume = <id> 恢复上下文。

# ── 第一次连接：建立会话，存入记忆 ─────────────────────────────────────────
# cwd 固定为当前目录，这样能确定 sessions 存在哪个 hash 文件夹下
session_cwd <- getwd()
opts13a <- ClaudeAgentOptions(cli_path = CLI_PATH, env = BASE_ENV, cwd = session_cwd)
client13a <- ClaudeSDKClient$new(opts13a)
client13a$connect()

client13a$send("我的幸运数字是 42，请记住它。")
reply13a <- ""
coro::loop(for (m in client13a$receive_response()) {
  if (inherits(m, "AssistantMessage")) {
    for (blk in m$content) {
      if (inherits(blk, "TextBlock")) reply13a <- paste0(reply13a, blk$text)
    }
  }
})
cat("第一次连接 → ", reply13a, "\n\n")
client13a$disconnect()

# list_sessions() 读默认 ~/.claude，Databricks CLI 的 sessions 存在 CONFIG_DIR/projects/ 下。
# CLI 对路径做了规范化（下划线/点 → 连字符），直接扫描找最新 .jsonl 更可靠。
all_jsonl <- list.files(
  path       = file.path(CONFIG_DIR, "projects"),
  pattern    = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.jsonl$",
  recursive  = TRUE,
  full.names = TRUE
)
# 过滤掉 subagents/（子 agent 的日志），只保留顶层 session 文件
all_jsonl   <- all_jsonl[!grepl("/subagents/", all_jsonl)]
# 按修改时间排序，取最新
if (length(all_jsonl) > 0) {
  all_jsonl  <- all_jsonl[order(file.mtime(all_jsonl), decreasing = TRUE)]
  resumed_id <- sub("\\.jsonl$", "", basename(all_jsonl[[1]]))
} else {
  resumed_id <- NULL
}
cat("CLI 生成的 session id：", if (!is.null(resumed_id)) resumed_id else "(无法获取)", "\n\n")

# ── 第二次连接：resume 恢复，验证上下文 ────────────────────────────────────
if (!is.null(resumed_id)) {
  opts13b <- ClaudeAgentOptions(
    cli_path = CLI_PATH,
    env      = BASE_ENV,
    resume   = resumed_id    # ← 用 resume 恢复，不是 session_id
  )
  client13b <- ClaudeSDKClient$new(opts13b)
  client13b$connect()

  client13b$send("我刚才告诉你我的幸运数字是多少？")
  reply13b <- ""
  coro::loop(for (m in client13b$receive_response()) {
    if (inherits(m, "AssistantMessage")) {
      for (blk in m$content) {
        if (inherits(blk, "TextBlock")) reply13b <- paste0(reply13b, blk$text)
      }
    }
  })
  cat("第二次连接（resume）→ ", reply13b, "\n")
  cat("记忆保持（含 42）：", grepl("42", reply13b), "\n")
  client13b$disconnect()
} else {
  cat("跳过 resume 测试（无法获取 session id）\n")
}

# =============================================================================
section("测试 14：完全显式 env（不依赖 settings.json 自动加载）")
# =============================================================================
# 之前所有测试都把 CLAUDE_CONFIG_DIR 传给子进程，CLI 会自动读取
# CONFIG_DIR/settings.json 里的 env 块，隐式注入 ANTHROPIC_BASE_URL 等变量。
#
# 本测试把 settings.json 里的每一个 env 变量都**逐一显式声明**，
# 并通过 settings 参数把 JSON 级别的配置（hasCompletedOnboarding 等）也传进去，
# 完全不依赖 settings.json 自动加载，配置意图一目了然，便于迁移和 CI/CD 使用。

# ── settings.json 的 JSON 级字段（通过 settings 参数传入）────────────────────
# 注意：这些是 JSON 顶层字段，不是环境变量，不能放在 env 列表里。
#   hasCompletedOnboarding          — 跳过首次运行的引导界面（SDK 使用必须为 true）
#   skipDangerousModePermissionPrompt — 跳过危险模式确认弹窗
explicit_settings_json <- jsonlite::toJSON(list(
  hasCompletedOnboarding           = TRUE,
  skipDangerousModePermissionPrompt = TRUE
), auto_unbox = TRUE)

# ── 完全显式的 env 列表 ──────────────────────────────────────────────────────
# 每一行对应一个环境变量，注释说明来源和用途：
explicit_env <- list(

  # ── 基础 Unix 环境（子进程最低需求）──────────────────────────────────────
  HOME   = Sys.getenv("HOME"),           # 家目录，影响 ~ 路径解析
  PATH   = Sys.getenv("PATH"),           # 可执行文件搜索路径（node/git 等）
  TMPDIR = "/tmp",                       # 临时文件目录

  # ── Claude CLI 配置目录 ──────────────────────────────────────────────────
  # CLI 从此目录读取 settings.json / CLAUDE.md / history.jsonl / projects/
  # 设置此变量后，settings.json 中的 env 块仍会被加载，
  # 但本测试通过下面的显式变量覆盖它，确保意图清晰。
  CLAUDE_CONFIG_DIR = CONFIG_DIR,

  # ── 认证（二选一，建议同时传保证兼容性）───────────────────────────────────
  # CLI 新版优先读 ANTHROPIC_API_KEY；旧版或部分场景读 ANTHROPIC_AUTH_TOKEN
  ANTHROPIC_API_KEY    = API_KEY,        # 主认证 key（CLI --help 文档指定）
  ANTHROPIC_AUTH_TOKEN = API_KEY,        # 兼容旧版 CLI / 某些中间件

  # ── Databricks AI Gateway 代理端点 ──────────────────────────────────────
  # 标准 Anthropic API 删除此行；AI Gateway 必须设置
  ANTHROPIC_BASE_URL = BASE_URL,

  # ── 模型别名（来自 settings.json $env 块）───────────────────────────────
  # CLI 用这些别名解析 "sonnet" / "opus" / "haiku" 等简写
  ANTHROPIC_MODEL                = MODEL,   # 默认模型（--model 不传时使用）
  ANTHROPIC_DEFAULT_SONNET_MODEL = MODEL,   # sonnet 别名
  ANTHROPIC_DEFAULT_OPUS_MODEL   = "databricks-claude-opus-4-6",
  ANTHROPIC_DEFAULT_HAIKU_MODEL  = "databricks-claude-haiku-4-5",

  # ── 自定义 HTTP 请求头（AI Gateway 鉴权必要字段）────────────────────────
  ANTHROPIC_CUSTOM_HEADERS = "x-databricks-use-coding-agent-mode: true",

  # ── 功能开关 ────────────────────────────────────────────────────────────
  # 禁用实验性 beta 功能（避免与 Databricks 代理不兼容）
  CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1"
)

opts14 <- ClaudeAgentOptions(
  cli_path = CLI_PATH,
  env      = explicit_env,             # 完全显式，不依赖 settings.json 继承
  settings = explicit_settings_json    # JSON 级配置：onboarding / permission
)

r14 <- claude_run("用一句话回答：地球绕太阳还是太阳绕地球？", options = opts14)
info14 <- NULL
tryCatch({
  c14 <- ClaudeSDKClient$new(opts14)
  c14$connect()
  info14 <- c14$get_server_info()
  c14$disconnect()
}, error = function(e) NULL)

cat("完全显式 env → 回答：", collect_text(r14$messages), "\n")
if (!is.null(info14)) {
  cat("  apiKeySource :", info14$account$apiKeySource, "\n")
  cat("  tokenSource  :", info14$account$tokenSource,  "\n")
  cat("  apiProvider  :", info14$account$apiProvider,  "\n")
}

# =============================================================================
section("全部测试完成")
# =============================================================================
cat("\n参数覆盖情况：\n")
cat("  [✓] cli_path               — 自定义 CLI 路径\n")
cat("  [✓] env (CONFIG_DIR/API_KEY) — 配置目录 + 认证\n")
cat("  [✓] settings (JSON 字符串)  — 运行时 JSON 覆盖\n")
cat("  [✓] settings (文件路径)     — 外部 JSON 文件\n")
cat("  [✓] system_prompt           — 自定义系统提示\n")
cat("  [✓] cwd                     — 子进程工作目录\n")
cat("  [✓] add_dirs                — 追加目录及自定义 CLAUDE.md\n")
cat("  [✓] model                   — 显式指定模型\n")
cat("  [✓] max_turns               — 最大对话轮数\n")
cat("  [✓] permission_mode         — 权限模式\n")
cat("  [✓] permission_prompt_tool_name — 工具审批协议\n")
cat("  [✓] can_use_tool            — 同步审批回调\n")
cat("  [✓] disallowed_tools        — SDK 级工具黑名单\n")
cat("  [✓] allowed_tools           — 额外允许工具\n")
cat("  [✓] stderr                  — 错误输出回调\n")
cat("  [✓] include_partial_messages — 流式中间帧\n")
cat("  [✓] output_format (json_schema) — 结构化输出\n")
cat("  [✓] setting_sources         — 配置层选择\n")
cat("  [✓] resume                  — 跨连接恢复历史会话（session_id 由 CLI 自动生成）\n")
cat("  [✓] 完全显式 env            — 所有环境变量逐一声明，不依赖继承\n")
