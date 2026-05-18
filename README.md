# Codex Desktop Reconnecting Fix / Codex 桌面端 Reconnecting 修复

Practical fixes for the Codex Desktop issue where a new conversation repeatedly shows:

```text
Reconnecting... 1/5
Reconnecting... 2/5
Reconnecting... 3/5
Reconnecting... 4/5
Reconnecting... 5/5
```

中文：这个仓库整理 Codex Desktop 新会话第一次提问时反复出现 `Reconnecting... 1/5` 到 `5/5` 的排查和修复方案。

## Tested Environment / 实测环境

- Windows 11
- Codex Desktop
- Codex CLI `0.130.0-alpha.5`
- Model: `gpt-5.5`
- Local proxy: `127.0.0.1:10808`
- Date tested: 2026-05-18

## Symptom / 现象

English:

- Codex Desktop can log in.
- `gpt-5.5` can work after retries.
- Every new conversation or first turn shows multiple reconnect attempts.
- Logs may include plugin sync failures, Cloudflare 403 responses, or conversation startup races.
- CLI may work only when proxy environment variables are set explicitly.

中文：

- Codex Desktop 可以登录。
- `gpt-5.5` 不是完全不可用，重试后有时能继续回答。
- 每次新建会话或第一次提问都会连续 `Reconnecting`。
- 日志里可能出现插件同步失败、Cloudflare 403、或者新会话状态初始化 race。
- CLI 在显式设置代理环境变量后可以正常调用模型。

## Recommended Fix / 推荐方案

This is the workaround that fixed the issue in our Windows Desktop setup while keeping `gpt-5.5`.

中文：这是本次实测有效的方案，可以继续使用 `gpt-5.5`，不是换模型。

### 1. Keep GPT-5.5, reduce startup pressure / 保留 GPT-5.5，降低启动压力

Edit:

```text
%USERPROFILE%\.codex\config.toml
```

Set:

```toml
model = "gpt-5.5"
model_reasoning_effort = "medium"
```

中文说明：`medium` 只是推理强度，不是换模型。连接稳定后可以再改回 `high` 或 `xhigh`。

### 2. Disable startup sync features temporarily / 临时关闭启动同步功能

Add or update:

```toml
[features]
apps = false
browser_use = false
browser_use_external = false
in_app_browser = false
computer_use = false
plugins = false
tool_search = false
tool_suggest = false
workspace_dependencies = false
```

Why:

- These features may trigger extra startup requests to `chatgpt.com` plugin/runtime endpoints.
- In some proxy environments, those requests may hit Cloudflare 403 or retry during new-thread startup.
- Reducing startup background work can avoid the reconnect loop.

中文说明：

- 这些功能会在启动或新会话阶段触发插件、浏览器、工具、运行时依赖同步。
- 在本地代理环境下，这些请求可能被 Cloudflare challenge 或代理链路拦住。
- 临时关闭它们可以减少新会话初始化时的失败重试。

### 3. Make Codex child processes inherit the proxy / 让 Codex 子进程继承代理

Run in PowerShell:

```powershell
setx HTTP_PROXY "http://127.0.0.1:10808"
setx HTTPS_PROXY "http://127.0.0.1:10808"
setx ALL_PROXY "http://127.0.0.1:10808"
setx NO_PROXY "localhost,127.0.0.1,::1"
```

Then fully quit Codex Desktop and start it again.

中文说明：

- 只设置 Windows 系统代理不一定能让 Codex 的 Rust 子进程稳定继承代理。
- 用户级环境变量可以让从桌面端启动的子进程更稳定地走本地代理。
- 设置后必须完全退出 Codex Desktop，再重新打开。

### 4. Optional: sync WinHTTP proxy / 可选：同步 WinHTTP 代理

If Codex Desktop still reconnects, open PowerShell as Administrator and run:

```powershell
netsh winhttp import proxy source=ie
netsh winhttp show proxy
```

中文说明：如果 `netsh winhttp show proxy` 显示 `Direct access`，而你的系统代理是 `127.0.0.1:10808`，可能存在用户代理和 WinHTTP 代理不一致。

## Alternative Fix: HTTP/SSE Provider / 备选方案：HTTP/SSE Provider

Creating a provider with `supports_websockets = false` can avoid WebSocket transport and use HTTP/SSE streaming instead.

中文：通过新增一个只走 HTTP/SSE 的 provider，可以绕开代理链路里的 WebSocket 抖动。

Example:

```toml
model_provider = "openai_http"
model = "gpt-5.5"
model_reasoning_effort = "medium"

[model_providers.openai_http]
name = "OpenAI HTTP only"
wire_api = "responses"
supports_websockets = false
requires_openai_auth = true
```

Important caveat:

In our ChatGPT-auth Desktop setup, this provider was not usable. It routed requests to:

```text
https://api.openai.com/v1/responses
```

and failed with:

```text
Missing scopes: api.responses.write
```

So treat this as an alternative, version-dependent workaround. If you see the missing-scope error, remove `model_provider = "openai_http"` and the `[model_providers.openai_http]` block.

中文注意：

在本次 ChatGPT 登录方式下，这个方案会触发 `api.responses.write` 权限不足。因此它不是通用方案。如果你遇到这个报错，应回退 provider 配置，只保留推荐方案里的代理环境变量和功能开关。

## Verification / 验证方法

Check feature flags:

```powershell
codex features list
```

Expected key values:

```text
apps                     false
browser_use              false
computer_use             false
plugins                  false
tool_search              false
workspace_dependencies   false
```

Test CLI through proxy:

```powershell
$env:HTTP_PROXY="http://127.0.0.1:10808"
$env:HTTPS_PROXY="http://127.0.0.1:10808"
$env:ALL_PROXY="http://127.0.0.1:10808"
codex exec --ephemeral --skip-git-repo-check "Reply only OK. Do not call tools."
```

If the output includes `OK` and shows `model: gpt-5.5`, the model call path is working.

中文：如果 CLI 能返回 `OK`，并显示 `model: gpt-5.5`，说明模型和账号本身可用，问题主要集中在 Desktop 启动链路、代理继承或启动同步功能。

## Rollback / 回退

1. Quit Codex Desktop.
2. Open `%USERPROFILE%\.codex\config.toml`.
3. Remove the `[features]` overrides if you need Apps, plugins, browser use, or workspace dependencies back.
4. Remove the HTTP/SSE provider block if you tried it and saw API scope errors.
5. Restart Codex Desktop.

To remove proxy environment variables:

```powershell
setx HTTP_PROXY ""
setx HTTPS_PROXY ""
setx ALL_PROXY ""
setx NO_PROXY ""
```

中文：如果后续 Codex 官方修复了这个问题，可以逐步恢复功能开关，先恢复 `plugins/apps/tool_search`，再恢复 `browser_use/computer_use`。

## Summary / 总结

English:

- If you must keep `gpt-5.5`, do not switch models first.
- First make sure Codex child processes inherit the local proxy.
- Disable startup sync features that can trigger extra failing requests.
- Try HTTP/SSE provider only if your Codex auth/version supports it.

中文：

- 如果必须使用 `gpt-5.5`，不需要先换模型。
- 优先确保 Codex 子进程能继承本地代理。
- 临时关闭会在启动阶段触发网络同步的功能。
- HTTP/SSE provider 可以作为备选，但不是所有 ChatGPT 登录环境都支持。
