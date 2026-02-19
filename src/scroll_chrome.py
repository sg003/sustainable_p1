import json
import time
import requests
import websocket
import argparse

SCROLL_EVERY = 1.2   # seconds between scrolls
SCROLL_PX = 900
PER_SITE_SECONDS = 30
NAV_WAIT = 5         # seconds after navigation before scrolling

URLS = [
    "https://www.dailymail.co.uk/home/index.html",
    "https://www.bbc.com/news",
    "https://www.theguardian.com/international",
]

def get_ws_url(port: int) -> str:
    tabs = requests.get(f"http://127.0.0.1:{port}/json", timeout=5).json()
    for tab in tabs:
        if tab.get("type") == "page" and tab.get("webSocketDebuggerUrl"):
            return tab["webSocketDebuggerUrl"]
    raise RuntimeError(f"No Chrome page found on DevTools port {port}")

def send(ws, method, params=None, msg_id=1):
    msg = {"id": msg_id, "method": method, "params": params or {}}
    ws.send(json.dumps(msg))
    return msg_id + 1

def scroll(ws, seconds, msg_id):
    end = time.time() + seconds
    while time.time() < end:
        msg_id = send(ws, "Runtime.evaluate", {
            "expression": f"window.scrollBy(0, {SCROLL_PX});"
        }, msg_id)
        time.sleep(SCROLL_EVERY)
    return msg_id

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9222)
    args = ap.parse_args()

    ws_url = get_ws_url(args.port)

    # IMPORTANT: set Origin (do NOT duplicate via header list)
    ws = websocket.create_connection(
        ws_url,
        origin=f"http://127.0.0.1:{args.port}",
        timeout=10,
    )

    msg_id = 1
    msg_id = send(ws, "Runtime.enable", msg_id=msg_id)
    msg_id = send(ws, "Page.enable", msg_id=msg_id)

    for url in URLS:
        msg_id = send(ws, "Page.navigate", {"url": url}, msg_id)
        time.sleep(NAV_WAIT)
        msg_id = scroll(ws, PER_SITE_SECONDS, msg_id)

    ws.close()

if __name__ == "__main__":
    main()
