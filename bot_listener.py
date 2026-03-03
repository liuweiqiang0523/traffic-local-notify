#!/usr/bin/env python3
"""Telegram command listener for traffic-local-notify (master-only).

Master mode supports remote node query via SSH:
- /traffic                 -> local report dry-run
- /traffic_send            -> local report send
- /selfcheck               -> local self-check
- /nodes                   -> list configured nodes
- /traffic <node>          -> query remote node dry-run (with fallback hints)
- /selfcheck <node>        -> remote self-check (with fallback hints)
- /help                    -> command help
"""

import json
import os
import shlex
import subprocess
import time
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional, Tuple

CFG = "/opt/traffic-local/config.json"
OFFSET_FILE = "/opt/traffic-local/bot.offset"
REPORT = "/opt/traffic-local/report.py"
NODES = "/opt/traffic-local/nodes.json"


def load_json(path: str, default: Any):
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


def parse_command(text: str) -> tuple[str, List[str]]:
    parts = text.strip().split()
    if not parts:
        return "", []
    cmd = parts[0].split("@")[0].lower()
    return cmd, parts[1:]


def run_local_report(args: List[str]) -> str:
    cmd = ["python3", REPORT] + args
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, timeout=120)
        return out.strip()
    except subprocess.CalledProcessError as e:
        return (e.output or str(e)).strip()
    except Exception as e:
        return f"ERROR: {e}"


def load_nodes() -> List[Dict[str, Any]]:
    return load_json(NODES, [])


def find_node(name: str) -> Optional[Dict[str, Any]]:
    q = name.strip().lower()
    for n in load_nodes():
        if str(n.get("name", "")).lower() == q:
            return n
    return None


def node_list_text() -> str:
    nodes = load_nodes()
    if not nodes:
        return "暂无 nodes.json（/opt/traffic-local/nodes.json）配置。"
    lines = ["可查询节点："]
    for n in nodes:
        lines.append(f"- {n.get('name')} ({n.get('host')}:{n.get('port',22)})")
    return "\n".join(lines)


def ssh_cmd_for_node(node: Dict[str, Any], report_args: List[str]) -> List[str]:
    host = node.get("host")
    user = node.get("user", "root")
    port = int(node.get("port", 22))
    key = node.get("key", "")

    remote_cmd = "python3 /opt/traffic-local/report.py " + " ".join(shlex.quote(a) for a in report_args)
    cmd = [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        "ConnectTimeout=10",
        "-p",
        str(port),
    ]
    if key:
        cmd += ["-i", key]
    cmd += [f"{user}@{host}", remote_cmd]
    return cmd


def classify_ssh_error(output: str) -> Tuple[str, List[str]]:
    t = output.lower()
    if "permission denied" in t:
        return "SSH 鉴权失败", [
            "确认主控机公钥已写入目标节点 ~/.ssh/authorized_keys",
            "确认 nodes.json 的 user/key 路径正确",
        ]
    if "no route to host" in t or "network is unreachable" in t:
        return "网络不可达", [
            "检查目标主机 IP/端口 是否正确",
            "检查安全组/防火墙是否放行 22 端口",
        ]
    if "connection timed out" in t or "operation timed out" in t:
        return "连接超时", [
            "检查节点在线状态",
            "检查 22 端口连通性（telnet/nc）",
        ]
    if "host key verification failed" in t:
        return "主机指纹校验失败", [
            "删除旧 known_hosts 记录后重试",
            "或手动 ssh 一次确认新指纹",
        ]
    if "could not resolve hostname" in t:
        return "主机名解析失败", [
            "检查 nodes.json 里的 host 是否写错",
            "建议直接填 IP",
        ]
    return "远程执行失败", [
        "检查 nodes.json 的 host/user/port/key",
        "在主控机手动 ssh 到该节点验证",
    ]


def run_remote(node: Dict[str, Any], report_args: List[str]) -> Tuple[bool, str]:
    if not node.get("host"):
        return False, "节点缺少 host"

    cmd = ssh_cmd_for_node(node, report_args)
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, timeout=180)
        return True, out.strip()
    except subprocess.CalledProcessError as e:
        return False, (e.output or str(e)).strip()
    except Exception as e:
        return False, str(e)


def format_remote_ok(node_name: str, body: str) -> str:
    return f"🛰️ 节点：{node_name}\n{body}"


def format_remote_fallback(node_name: str, err: str, fallback: str) -> str:
    reason, tips = classify_ssh_error(err)
    tip_text = "\n".join(f"- {x}" for x in tips)
    return (
        f"❌ 远程查询失败（节点: {node_name}）\n"
        f"原因：{reason}\n"
        f"\n建议：\n{tip_text}\n"
        f"\n---- 自动回落：主控机本地结果 ----\n{fallback}"
    )


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
        "/traffic - 查看主控机当前流量\n"
        "/traffic <node> - 查看指定节点流量\n"
        "/traffic_send - 主控机立即推送一条通知\n"
        "/selfcheck - 主控机自检\n"
        "/selfcheck <node> - 指定节点自检\n"
        "/nodes - 列出可查询节点\n"
        "/help - 查看帮助"
    )

    while True:
        try:
            res = api_request(
                token,
                "getUpdates",
                {
                    "timeout": "60",
                    "offset": str(offset),
                    "allowed_updates": json.dumps(["message"]),
                },
            )
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
                cmd, args = parse_command(text)

                if cmd == "/traffic":
                    if args:
                        node = find_node(args[0])
                        if not node:
                            send_message(token, chat_id, f"未找到节点：{args[0]}\n发送 /nodes 查看可用节点", thread_id)
                        else:
                            ok, out = run_remote(node, ["--dry-run"])
                            if ok:
                                send_message(token, chat_id, format_remote_ok(node["name"], out or "(无输出)"), thread_id)
                            else:
                                local_fb = run_local_report(["--dry-run"])
                                send_message(token, chat_id, format_remote_fallback(node["name"], out, local_fb), thread_id)
                    else:
                        out = run_local_report(["--dry-run"])
                        send_message(token, chat_id, out or "(无输出)", thread_id)

                elif cmd == "/traffic_send":
                    _ = run_local_report(["--send"])
                    send_message(token, chat_id, "✅ 已触发主控机推送", thread_id)

                elif cmd == "/selfcheck":
                    if args:
                        node = find_node(args[0])
                        if not node:
                            send_message(token, chat_id, f"未找到节点：{args[0]}\n发送 /nodes 查看可用节点", thread_id)
                        else:
                            ok, out = run_remote(node, ["--self-check"])
                            if ok:
                                send_message(token, chat_id, format_remote_ok(node["name"], out or "(无输出)"), thread_id)
                            else:
                                local_fb = run_local_report(["--self-check"])
                                send_message(token, chat_id, format_remote_fallback(node["name"], out, local_fb), thread_id)
                    else:
                        out = run_local_report(["--self-check"])
                        send_message(token, chat_id, out or "(无输出)", thread_id)

                elif cmd == "/nodes":
                    send_message(token, chat_id, node_list_text(), thread_id)

                elif cmd == "/help":
                    send_message(token, chat_id, help_text, thread_id)

                else:
                    send_message(token, chat_id, "未知命令。发送 /help 查看可用命令。", thread_id)

        except Exception:
            time.sleep(3)


if __name__ == "__main__":
    main()
