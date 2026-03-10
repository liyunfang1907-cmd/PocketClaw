#!/usr/bin/env python3
"""
PocketClaw Gateway Route Injector

Patches OpenClaw's gateway-cli JS files to serve custom static files
(e.g. mobile.html) before the canvasHost SPA handler intercepts them.

Why this is needed:
  canvasHost.handleHttpRequest runs before handleControlUiHttpRequest,
  intercepting ALL page requests and returning index.html (SPA behavior).
  This patch inserts a handler BEFORE canvasHost to serve our custom files
  directly from disk.

Usage:
  GW_DIR=/path/to/dist CONTROL_UI_DIR=/path/to/control-ui python3 gateway-patch.py
"""
import os, sys, glob

def find_gateway_files(gw_dir):
    """Find all gateway-cli JS files in the given directory."""
    return glob.glob(os.path.join(gw_dir, "gateway-cli-*.js"))

def build_injection_code(ui_dir):
    """Build the JavaScript code to inject before canvasHost."""
    escaped_dir = ui_dir.replace("\\", "\\\\")
    return (
        "\t\t\t\t{\n"
        "\t\t\t\t\tconst _pocketClawCustomFiles = {\n"
        "\t\t\t\t\t\t'/mobile.html': 'text/html; charset=utf-8'\n"
        "\t\t\t\t\t};\n"
        "\t\t\t\t\tconst _pcMime = _pocketClawCustomFiles[requestPath];\n"
        "\t\t\t\t\tif (_pcMime && requestPath.indexOf('..') === -1 && requestPath.indexOf('\\\\') === -1) {\n"
        "\t\t\t\t\t\ttry {\n"
        "\t\t\t\t\t\t\tconst _pcFs = await import('node:fs');\n"
        f"\t\t\t\t\t\t\tconst _pcData = _pcFs.default.readFileSync('{escaped_dir}' + requestPath);\n"
        "\t\t\t\t\t\t\tres.writeHead(200, { 'Content-Type': _pcMime, 'Cache-Control': 'no-cache', "
        "'Content-Security-Policy': \"default-src 'self'; script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
        "img-src 'self' data: https:; font-src 'self' https://fonts.gstatic.com; "
        "connect-src 'self' ws: wss:; base-uri 'none'; object-src 'none'; frame-ancestors 'none'\" });\n"
        "\t\t\t\t\t\t\tres.end(_pcData);\n"
        "\t\t\t\t\t\t\treturn;\n"
        "\t\t\t\t\t\t} catch(_pcErr) { /* fall through */ }\n"
        "\t\t\t\t\t} else if (_pcMime) {\n"
        "\t\t\t\t\t\tconsole.error('[PocketClaw] 🚫 blocked suspicious path:', requestPath);\n"
        "\t\t\t\t\t}\n"
        "\t\t\t\t\tif (requestPath === '/api-info') {\n"
        "\t\t\t\t\t\ttry {\n"
        "\t\t\t\t\t\t\tconst _pcFs = await import('node:fs');\n"
        "\t\t\t\t\t\t\tconst _pcData = _pcFs.default.readFileSync('/home/node/.openclaw/api-status.json');\n"
        "\t\t\t\t\t\t\tres.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-cache' });\n"
        "\t\t\t\t\t\t\tres.end(_pcData);\n"
        "\t\t\t\t\t\t\treturn;\n"
        "\t\t\t\t\t\t} catch(_pcErr) {\n"
        "\t\t\t\t\t\t\tres.writeHead(200, { 'Content-Type': 'application/json' });\n"
        "\t\t\t\t\t\t\tres.end('{}');\n"
        "\t\t\t\t\t\t\treturn;\n"
        "\t\t\t\t\t\t}\n"
        "\t\t\t\t\t}\n"
        "\t\t\t\t}\n"
    )

def patch_file(gw_file, inject_code):
    """Patch a single gateway-cli JS file. Returns True if successful."""
    basename = os.path.basename(gw_file)
    try:
        with open(gw_file, "r") as f:
            content = f.read()
    except (PermissionError, OSError) as e:
        print(f"  ⚠️  无法读取 {basename}: {e}")
        return False

    # 幂等性: 已注入则跳过
    if "_pocketClawCustomFiles" in content:
        return True

    # 查找注入点: handleRequest → if (canvasHost) {
    hr = content.find("async function handleRequest(req, res)")
    if hr == -1:
        # 尝试替代函数签名（OpenClaw 版本兼容）
        hr = content.find("async function handleRequest(")
    if hr == -1:
        print(f"  ⚠️  {basename}: 未找到 handleRequest 函数")
        return False

    target = content.find("if (canvasHost) {", hr)
    if target == -1:
        # 尝试替代模式
        target = content.find("if(canvasHost){", hr)
    if target == -1:
        print(f"  ⚠️  {basename}: 未找到 canvasHost 注入点")
        return False

    # 备份原始文件
    backup_path = gw_file + ".pc-backup"
    if not os.path.exists(backup_path):
        try:
            with open(backup_path, "w") as bf:
                bf.write(content)
        except OSError:
            pass  # 备份失败不阻止注入

    # 注入
    new_content = content[:target] + inject_code + content[target:]
    try:
        with open(gw_file, "w") as f:
            f.write(new_content)
        return True
    except (PermissionError, OSError) as e:
        print(f"  ⚠️  无法写入 {basename}: {e}")
        return False

def main():
    gw_dir = os.environ.get("GW_DIR", "")
    ui_dir = os.environ.get("CONTROL_UI_DIR", "")

    if not gw_dir or not ui_dir:
        print("  ⚠️  缺少 GW_DIR 或 CONTROL_UI_DIR 环境变量")
        sys.exit(1)

    gw_files = find_gateway_files(gw_dir)
    if not gw_files:
        print(f"  ⚠️  未找到 gateway-cli-*.js 文件 (目录: {gw_dir})")
        sys.exit(1)

    inject_code = build_injection_code(ui_dir)
    patched = False

    for gw_file in gw_files:
        if patch_file(gw_file, inject_code):
            patched = True

    if patched:
        print("  ✅ Gateway 自定义路由已注入")
    else:
        print("  ⚠️  Gateway 路由注入失败（mobile.html 可能无法访问）")
        sys.exit(1)

if __name__ == "__main__":
    main()
