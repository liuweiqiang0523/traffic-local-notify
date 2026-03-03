#!/usr/bin/env python3
"""traffic-local-notify

Monthly traffic reporter based on vnStat.
- Tracks per-server traffic cycle (custom billing day/time)
- Maintains recent history in /opt/traffic-local/state.json
- Sends Telegram notifications on thresholds or forced send
"""

import argparse
import datetime
import json
import os
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, Tuple

CFG = "/opt/traffic-local/config.json"
STA = "/opt/traffic-local/state.json"


class ReportError(Exception):
    """User-friendly runtime error for report generation."""


def load_json(path: str, default: Dict[str, Any]) -> Dict[str, Any]:
    if not os.path.exists(path):
        return default
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        raise ReportError(f"JSON 格式错误: {path} ({e})") from e


def save_json(path: str, data: Dict[str, Any]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def tb(v: float) -> float:
    return v / (1024 ** 4)


def gb(v: float) -> float:
    return v / (1024 ** 3)


def fmt(ts: int) -> str:
    return datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")


def cycle_start(now: datetime.datetime, day: int, hms: str) -> datetime.datetime:
    h, m, s = map(int, hms.split(":"))
    current = datetime.datetime(now.year, now.month, day, h, m, s, tzinfo=now.tzinfo)
    if now >= current:
        return current

    y, mo = now.year, now.month - 1
    if mo == 0:
        y, mo = y - 1, 12
    return datetime.datetime(y, mo, day, h, m, s, tzinfo=now.tzinfo)


def tg_send(token: str, chat_id: str, text: str) -> None:
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    body = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
    req = urllib.request.Request(url, data=body, method="POST")
    try:
        urllib.request.urlopen(req, timeout=20).read()
    except urllib.error.URLError as e:
        raise ReportError(f"Telegram 推送失败: {e}") from e


def detect_default_interface() -> str:
    try:
        out = subprocess.check_output(
            ["bash", "-lc", "ip -o -4 route show to default | awk '{print $5}' | head -n1"],
            text=True,
            stderr=subprocess.STDOUT,
        ).strip()
        if out:
            return out
    except Exception:
        pass
    return "eth0"


def get_vnstat_json() -> Dict[str, Any]:
    try:
        raw = subprocess.check_output(["vnstat", "--json"], text=True, stderr=subprocess.STDOUT)
    except FileNotFoundError as e:
        raise ReportError("未找到 vnstat，请先安装: apt-get install -y vnstat") from e
    except subprocess.CalledProcessError as e:
        raise ReportError(f"vnstat 执行失败: {e.output.strip()}") from e

    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise ReportError(f"vnstat 输出 JSON 解析失败: {e}") from e


def get_vnstat_totals(vn_data: Dict[str, Any], interface: str) -> Tuple[int, int]:
    for itf in vn_data.get("interfaces", []):
        if itf.get("name") == interface:
            total = itf.get("traffic", {}).get("total", {})
            rx = total.get("rx")
            tx = total.get("tx")
            if rx is None or tx is None:
                break
            return int(rx), int(tx)

    all_ifaces = [itf.get("name") for itf in vn_data.get("interfaces", []) if itf.get("name")]
    raise ReportError(f"找不到网卡 {interface} 的 vnstat total 数据。可用网卡: {', '.join(all_ifaces) or '无'}")


def build_message(cfg: Dict[str, Any], st: Dict[str, Any], cur_rx: int, cur_tx: int) -> str:
    cur_sum = cur_rx + cur_tx
    used_gb = gb(cur_sum)
    limit_gb = float(cfg["limit_gb"])
    pct = (used_gb / limit_gb * 100) if limit_gb > 0 else 0

    msg = (
        f"🖥️ 服务器：{cfg['server_name']}\n"
        f"🕐 周期起始：{fmt(st['cycle_start_ts'])}\n"
        f"🌐 网卡：{cfg['interface']}\n"
        f"⬇️ 入站流量：{tb(cur_rx):>8.2f} TB\n"
        f"⬆️ 出站流量：{tb(cur_tx):>8.2f} TB\n"
        f"📈 已用流量：{tb(cur_sum):>8.2f} TB\n"
        f"📊 流量限额：{limit_gb:>8,.0f} GB（{pct:>5.1f}%）\n"
        f"📋 历史流量：\n"
    )

    if st["history"]:
        for h in st["history"][-3:][::-1]:
            msg += (
                f"  • {fmt(h['cycle_start_ts'])}  "
                f"总用量 {h['sum_tb']:>6.2f} TB / 限额 {h['limit_gb']:>7,.0f} GB\n"
            )
    else:
        msg += "  • 暂无历史记录\n"

    return msg


def validate_config(cfg: Dict[str, Any]) -> None:
    required = [
        "server_name",
        "interface",
        "limit_gb",
        "billing_day",
        "billing_hms",
        "telegram_bot_token_file",
        "telegram_chat_id",
    ]
    missing = [k for k in required if k not in cfg]
    if missing:
        raise ReportError(f"配置缺少字段: {', '.join(missing)}")

    if not isinstance(cfg["billing_day"], int):
        raise ReportError("billing_day 必须是整数")
    if cfg["billing_day"] < 1 or cfg["billing_day"] > 28:
        raise ReportError("billing_day 建议范围 1~28，避免短月问题")

    try:
        datetime.datetime.strptime(cfg["billing_hms"], "%H:%M:%S")
    except ValueError as e:
        raise ReportError("billing_hms 格式必须是 HH:MM:SS") from e

    if float(cfg["limit_gb"]) <= 0:
        raise ReportError("limit_gb 必须 > 0")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--send", action="store_true", help="强制推送 Telegram")
    parser.add_argument("--dry-run", action="store_true", help="只输出，不推送")
    parser.add_argument("--show-config", action="store_true", help="显示当前生效配置")
    args = parser.parse_args()

    cfg = load_json(CFG, {})
    if not cfg:
        raise ReportError(f"缺少配置文件：{CFG}")

    # interface 支持 auto
    iface = str(cfg.get("interface", "auto")).strip().lower()
    if iface in ("", "auto"):
        cfg["interface"] = detect_default_interface()

    validate_config(cfg)

    if args.show_config:
        print(json.dumps(cfg, ensure_ascii=False, indent=2))

    vn_data = get_vnstat_json()
    rx, tx = get_vnstat_totals(vn_data, cfg["interface"])

    now = datetime.datetime.now().astimezone()
    cstart = int(cycle_start(now, int(cfg["billing_day"]), cfg["billing_hms"]).timestamp())

    st = load_json(
        STA,
        {
            "cycle_start_ts": cstart,
            "start_rx": rx,
            "start_tx": tx,
            "history": [],
            "alerted": [],
        },
    )

    # Cycle rollover
    if st.get("cycle_start_ts") != cstart:
        prev_rx = max(0, rx - int(st.get("start_rx", rx)))
        prev_tx = max(0, tx - int(st.get("start_tx", tx)))
        prev_sum = prev_rx + prev_tx

        st.setdefault("history", []).append(
            {
                "cycle_start_ts": st.get("cycle_start_ts", cstart),
                "in_tb": round(tb(prev_rx), 2),
                "out_tb": round(tb(prev_tx), 2),
                "sum_tb": round(tb(prev_sum), 2),
                "limit_gb": cfg["limit_gb"],
            }
        )
        st["history"] = st["history"][-12:]
        st["cycle_start_ts"] = cstart
        st["start_rx"] = rx
        st["start_tx"] = tx
        st["alerted"] = []

    cur_rx = max(0, rx - int(st.get("start_rx", rx)))
    cur_tx = max(0, tx - int(st.get("start_tx", tx)))
    cur_sum = cur_rx + cur_tx

    limit_gb = float(cfg["limit_gb"])
    pct = (gb(cur_sum) / limit_gb * 100) if limit_gb > 0 else 0

    alert_levels = cfg.get("alert_levels", [80, 90, 100])
    need_alert = False
    for lv in alert_levels:
        key = str(int(lv))
        if pct >= float(lv) and key not in st.get("alerted", []):
            st.setdefault("alerted", []).append(key)
            need_alert = True

    save_json(STA, st)

    msg = build_message(cfg, st, cur_rx, cur_tx)
    print(msg.strip())
    print("OK")

    if args.dry_run:
        return

    should_send = args.send or bool(cfg.get("send_always", False)) or need_alert
    if should_send:
        token_file = cfg["telegram_bot_token_file"]
        if not os.path.exists(token_file):
            raise ReportError(f"缺少 token 文件：{token_file}")
        bot_token = open(token_file, "r", encoding="utf-8").read().strip()
        if not bot_token:
            raise ReportError(f"token 文件为空：{token_file}")
        tg_send(bot_token, cfg["telegram_chat_id"], msg[:3900])


if __name__ == "__main__":
    try:
        main()
    except ReportError as e:
        print(f"ERROR: {e}")
        raise SystemExit(1)
