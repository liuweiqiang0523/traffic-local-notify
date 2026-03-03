#!/usr/bin/env python3
"""Telegram command listener for traffic-local-notify.

Commands:
- /traffic      -> run report.py --dry-run and reply in chat/topic
- /traffic_send -> run report.py --send (push report)
- /selfcheck    -> run report.py --self-check and reply
- /help         -> show command help
"""

import json
import os
import subprocess
import time
import urllib.parse
import urllib.request
from typing import Any, Dict, Optional

CFG = "/opt/traffic-local/config.json"
OFFSET_FILE = "/opt/traffic-local/bot.offset"
REPORT = "/opt/traffic-local/report.py"


def load_json(path: str, default: Dict[str, Any]) -> Dict[str, Any]:
    if not os.path.exists(path):
        return default
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_offset(offset: int) -> None:
    with open(OFFSET_FILE, "w", encoding="utf-8") as f:
        f.write(str(offset))


def load_offset() -> int:
    if not os.path.exists(OFFSET_FILE):
        return 0
    try:
        return int(open(OFFSET_FILE, "r", encoding="utf-8").read().strip())
    except Exception:
        return 0


def api_request(token: str, method: str, params: Dict[str, Any]) -> Dict[str, Any]:
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    with urllib.request.urlopen(req, timeout=70) as resp:
        raw = resp.read().decode("utf-8")
    return json.loads(raw)


def send_message(token: str, chat_id: str, text: str, thread_id: Optional[int] = None) -> None:
    chunks = [text[i : i + 3900] for i in range(0, len(text), 3900)] or [""]
    for chunk in chunks:
        payload: Dict[str, Any] = {"chat_id": chat_id, "text": chunk}
        if thread_id is not None:
            payload["message_thread_id"] = str(thread_id)
        api_request(token, "sendMessage", payload)


def run_report(args: list[str]) -> str:
    cmd = ["python3", REPORT] + args
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, timeout=120)
        return out.strip()
    except subprocess.CalledProcessError as e:
        return (e.output or str(e)).strip()
    except Exception as e:
        return f"ERROR: {e}"


def parse_command(text: str) -> str:
    first = text.strip().split()[0] if text.strip() else ""
    cmd = first.split("@")[0].lower()
    return cmd


def main() -> None:
    cfg = load_json(CFG, {})
    token_file = cfg.get("telegram_bot_token_file", "/opt/traffic-local/tg_bot_token.txt")
    chat_id_allow = str(cfg.get("telegram_chat_id", "")).strip()

    if not chat_id_allow:
        raise SystemExit("config 缺少 telegram_chat_id")
    if not os.path.exists(token_file):
        raise SystemExit(f"缺少 token 文件: {token_file}")

    token = open(token_file, "r", encoding="utf-8").read().strip()
    if not token:
        raise SystemExit(f"token 文件为空: {token_file}")

    offset = load_offset()

    help_text = (
        "可用命令：\n"
        "/traffic - 查看当前流量\n"
        "/traffic_send - 立即推送一条流量通知\n"
        "/selfcheck - 执行自检\n"
        "/help - 查看帮助"
    )

    while True:
        try:
            res = api_request(token, "getUpdates", {
                "timeout": "60",
                "offset": str(offset),
                "allowed_updates": json.dumps(["message"]),
            })
            if not res.get("ok"):
                time.sleep(3)
                continue

            for upd in res.get("result", []):
                offset = int(upd.get("update_id", 0)) + 1
                save_offset(offset)

                msg = upd.get("message")
                if not msg:
                    continue

                chat = msg.get("chat", {})
                chat_id = str(chat.get("id", ""))
                if chat_id != chat_id_allow:
                    continue

                text = msg.get("text", "")
                if not text.startswith("/"):
                    continue

                thread_id = msg.get("message_thread_id")
                cmd = parse_command(text)

                if cmd == "/traffic":
                    out = run_report(["--dry-run"])
                    send_message(token, chat_id, out or "(无输出)", thread_id)
                elif cmd == "/traffic_send":
                    _ = run_report(["--send"])
                    send_message(token, chat_id, "✅ 已触发推送", thread_id)
                elif cmd == "/selfcheck":
                    out = run_report(["--self-check"])
                    send_message(token, chat_id, out or "(无输出)", thread_id)
                elif cmd == "/help":
                    send_message(token, chat_id, help_text, thread_id)
                else:
                    send_message(token, chat_id, "未知命令。发送 /help 查看可用命令。", thread_id)

        except Exception:
            time.sleep(3)


if __name__ == "__main__":
    main()
