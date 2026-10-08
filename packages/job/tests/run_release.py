"""Run the compiled JOB browser regression with Python Playwright."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread

from playwright.sync_api import sync_playwright


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chromium", help="optional Chromium executable path")
    options = parser.parse_args()
    directory = Path(__file__).resolve().parent
    if not (directory / "testrelease.js").is_file():
        parser.error("compile testrelease.lpr first (see README.md)")
    server = ThreadingHTTPServer(
        ("127.0.0.1", 0), partial(QuietHandler, directory=str(directory))
    )
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with sync_playwright() as playwright:
            launch_options = {"headless": True}
            if options.chromium:
                launch_options["executable_path"] = options.chromium
            browser = playwright.chromium.launch(**launch_options)
            page = browser.new_page()
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(f"http://127.0.0.1:{server.server_port}/testrelease.html")
            result = page.locator("body").inner_text().strip()
            browser.close()
            if errors or not result.startswith("PASS:"):
                raise AssertionError(f"JOB regression failed: {result}; errors={errors}")
            print(result)
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == "__main__":
    main()
