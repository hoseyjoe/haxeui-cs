"""Photographs the html5 gallery and sets each page under its haxeui-cs twin.

Run from the repo root after both gallery builds and the cs runs:
    python -I tools/gallery/compare.py

Serves tools/gallery/web on localhost:8765, photographs every page the cs run
wrote (tools/gallery/out/page<n>[-dark].png) with headless Edge at 1440x900,
and writes tools/gallery/out/compare/page<n>[-dark].png: the top 430 px of the
cs page above the same strip of the html5 page.
"""
import functools
import http.server
import os
import re
import subprocess
import threading
import time

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__)))
WEB = os.path.join(ROOT, "web")
OUT = os.path.join(ROOT, "out")
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
PORT = 8765
STRIP = (0, 0, 1410, 430)


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve():
    handler = functools.partial(QuietHandler, directory=WEB)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def photograph(page, dark, path):
    if os.path.exists(path):
        os.remove(path)
    url = f"http://localhost:{PORT}/index.html?page={page}&dark={1 if dark else 0}"
    subprocess.run([EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--window-size=1440,900",
                    "--virtual-time-budget=4000", f"--screenshot={path}", url],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    # msedge.exe hands the work to a child and returns first: wait for the file to land and settle.
    last = -1
    for _ in range(60):
        size = os.path.getsize(path) if os.path.exists(path) else -1
        if size > 0 and size == last:
            return True
        last = size
        time.sleep(0.25)
    return False


def main():
    pages = sorted(int(m.group(1)) for m in (re.fullmatch(r"page(\d+)\.png", f) for f in os.listdir(OUT)) if m)
    if not pages:
        raise SystemExit("compare: no cs pages in tools/gallery/out; run the cs gallery first")
    os.makedirs(os.path.join(OUT, "html5"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "compare"), exist_ok=True)
    server = serve()
    try:
        for dark in (False, True):
            suffix = "-dark" if dark else ""
            for page in pages:
                cs_path = os.path.join(OUT, f"page{page}{suffix}.png")
                web_path = os.path.join(OUT, "html5", f"page{page}{suffix}.png")
                if not os.path.exists(cs_path):
                    continue
                # Edge now and then exits without writing; one retry covers it.
                if not (photograph(page, dark, web_path) or photograph(page, dark, web_path)):
                    print(f"compare: no html5 picture for page {page}{suffix}")
                    continue
                strip_h = STRIP[3] - STRIP[1]
                sheet = Image.new("RGB", (STRIP[2], strip_h * 2 + 20), (255, 0, 255))
                sheet.paste(Image.open(cs_path).convert("RGB").crop(STRIP), (0, 0))
                sheet.paste(Image.open(web_path).convert("RGB").crop(STRIP), (0, strip_h + 20))
                ImageDraw.Draw(sheet).text((4, strip_h + 3), "^ haxeui-cs     v html5", fill=(0, 0, 0))
                sheet.save(os.path.join(OUT, "compare", f"page{page}{suffix}.png"))
                print(f"compare: page{page}{suffix}")
    finally:
        server.shutdown()


if __name__ == "__main__":
    main()
