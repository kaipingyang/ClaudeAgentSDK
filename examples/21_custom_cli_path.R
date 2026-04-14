## Example 21 — Custom CLI path & environment (Databricks AI Gateway)
##
## 适用场景：
##   - 使用非系统默认路径的 Claude Code CLI（如企业内网部署、Databricks AI Gateway）
##   - 需要为子进程注入特定环境变量（BASE_URL、API_KEY、配置目录等）
##   - 验证自定义 CLI 是否可用、认证是否正确
##
## 使用前准备：
##   1. 确认 CLI 可执行：system2("/path/to/claude", "--version") 应输出版本号
##   2. 确认认证 token：Sys.getenv("ANTHROPIC_AUTH_TOKEN") 非空
##   3. settings.json 已配置 ANTHROPIC_BASE_URL 和 ANTHROPIC_MODEL
##
## 注意：Databricks AI Gateway 的 CLI 不产生逐 token 的 StreamEvent，
##       直接以完整 AssistantMessage 返回（标准 Anthropic API 则会有 StreamEvent）。

library(ClaudeAgentSDK)

# ── 1. 定义 Options ──────────────────────────────────────────────────────────

OPTS <- ClaudeAgentOptions(
  cli_path = "/mnt/usrfiles/bgcrh/support/sp_app/claude_code/bin/claude",
  env = list(
    # Claude CLI 读取配置文件的目录（包含 settings.json、CLAUDE.md 等）
    CLAUDE_CONFIG_DIR = "/mnt/usrfiles/bgcrh/support/sp_app/claude_code/.claude",
    # CLI 使用 ANTHROPIC_API_KEY 作为认证（不是 ANTHROPIC_AUTH_TOKEN）
    # 从 R session 的 ANTHROPIC_AUTH_TOKEN 映射过来
    ANTHROPIC_API_KEY = Sys.getenv("ANTHROPIC_AUTH_TOKEN")
  )
)

# ── 2. 预检：确认 CLI 可访问 + API Key 非空 ──────────────────────────────────

cat("=== CLI 版本检查 ===\n")
version_out <- tryCatch(
  system2(OPTS$cli_path, "--version", stdout = TRUE, stderr = TRUE),
  error = function(e) stop("CLI 不可执行：", conditionMessage(e))
)
cat(version_out, sep = "\n")

api_key <- OPTS$env[["ANTHROPIC_API_KEY"]]
if (is.null(api_key) || !nzchar(api_key)) {
  stop(
    "ANTHROPIC_API_KEY 为空。\n",
    "请确认 Sys.getenv('ANTHROPIC_AUTH_TOKEN') 已设置，\n",
    "或直接在 env 列表中硬编码（测试环境仅，勿提交）。"
  )
}
cat("API Key 前缀：", substr(api_key, 1, 8), "...\n\n")

# ── 3. 一次性调用（claude_run）───────────────────────────────────────────────

cat("=== 测试 1：claude_run（同步一次性调用）===\n")
run_result <- claude_run("用一句话回答：1+1等于几？", options = OPTS)

# claude_run 返回 ClaudeRunResult，文本在 $messages 里的 AssistantMessage 中
for (msg in run_result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (blk in msg$content) {
      if (inherits(blk, "TextBlock") && nzchar(blk$text)) {
        cat("回答：", blk$text, "\n")
      }
    }
  }
  if (inherits(msg, "ResultMessage")) {
    cat("stop_reason:", msg$stop_reason,
        "| turns:", msg$num_turns,
        "| output_tokens:", msg$usage$output_tokens, "\n")
  }
}
cat("\n")

# ── 4. 流式调用（claude_query）───────────────────────────────────────────────

cat("=== 测试 2：claude_query（生成器）===\n")
# 注意：Databricks AI Gateway 的 CLI 不产生 StreamEvent，
# 直接返回完整 AssistantMessage（等同于非流式模式）
gen <- claude_query("列出三种水果，每行一个", options = OPTS)
coro::loop(
  for (msg in gen) {
    if (inherits(msg, "StreamEvent")) {
      # 标准 Anthropic API 走这里（逐 token 流式输出）
      delta <- msg$delta
      if (!is.null(delta[["type"]]) && delta[["type"]] == "text_delta") {
        cat(delta[["text"]])
      }
    } else if (inherits(msg, "AssistantMessage")) {
      # Databricks AI Gateway 走这里（完整消息一次性返回）
      for (blk in msg$content) {
        if (inherits(blk, "TextBlock") && nzchar(blk$text)) cat(blk$text)
      }
    } else if (inherits(msg, "ResultMessage")) {
      cat("\n[stop_reason:", msg$stop_reason,
          "| tokens:", msg$usage$output_tokens, "]\n")
    }
  }
)
cat("\n")

# ── 5. 多轮会话（ClaudeSDKClient）────────────────────────────────────────────

cat("=== 测试 3：ClaudeSDKClient 多轮会话 ===\n")
client <- ClaudeSDKClient$new(OPTS)
client$connect()

# 查看 CLI 初始化信息
info <- client$get_server_info()
cat("连接成功！\n")
cat("  API Key 来源：", info$account$apiKeySource, "\n")
cat("  Token 来源：",   info$account$tokenSource,  "\n")
cat("  API 提供商：",   info$account$apiProvider,  "\n")
cat("  可用模型数：",   length(info$models), "\n\n")

# 辅助函数：从消息列表提取文本
collect_text <- function(client) {
  text <- ""
  coro::loop(
    for (msg in client$receive_response()) {
      if (inherits(msg, "AssistantMessage")) {
        for (blk in msg$content) {
          if (inherits(blk, "TextBlock") && nzchar(blk$text)) {
            text <- paste0(text, blk$text)
          }
        }
      }
    }
  )
  text
}

# 第一轮
client$send("你好，请问你是哪个 AI 模型？")
reply1 <- collect_text(client)
cat("第一轮：", reply1, "\n\n")

# 第二轮（验证上下文保持）
client$send("把你刚才的回答翻译成英文。")
reply2 <- collect_text(client)
cat("第二轮（英文）：", reply2, "\n\n")

client$disconnect()
cat("连接已关闭。\n\n")

# ── 6. 工具调用（permission_prompt_tool_name = "stdio"）────────────────────

cat("=== 测试 4：工具调用（自动放行）===\n")
tool_opts <- ClaudeAgentOptions(
  cli_path                    = OPTS$cli_path,
  env                         = OPTS$env,
  permission_prompt_tool_name = "stdio",
  can_use_tool = function(name, input, ctx) {
    cat("  [工具审批] 放行：", name, "\n")
    PermissionResultAllow()
  }
)

tool_result <- claude_run(
  "读取 /dev/null 的内容并告诉我它有多少字节",
  options = tool_opts
)
for (msg in tool_result$messages) {
  if (inherits(msg, "AssistantMessage")) {
    for (blk in msg$content) {
      if (inherits(blk, "TextBlock") && nzchar(blk$text)) cat("回答：", blk$text, "\n")
    }
  }
}
cat("\n")

# ── 7. 全部完成 ──────────────────────────────────────────────────────────────

cat("=== 全部测试完成 ===\n")
cat("\n常见问题排查：\n")
cat("  403 Invalid access to Org  → ANTHROPIC_API_KEY 为空，检查 Sys.getenv('ANTHROPIC_AUTH_TOKEN')\n")
cat("  CLI not found              → cli_path 不存在或不可执行\n")
cat("  apiKeySource: none         → ANTHROPIC_API_KEY 未传入 env 列表\n")
cat("  无文本输出                 → Databricks CLI 不产生 StreamEvent，需检查 AssistantMessage\n")
