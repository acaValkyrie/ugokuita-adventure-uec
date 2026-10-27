#!/usr/bin/env python3
"""Web ベンチマーク用の帯域制限付き静的サーバー。"""

import argparse
import gzip
import math
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit


CHUNK_SIZE = 64 * 1024
CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "application/javascript",
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".json": "application/json",
    ".png": "image/png",
}


class BandwidthLimiter:
    def __init__(self, mbps):
        self.rate = mbps * 1_000_000 / 8
        self.lock = threading.Lock()
        self.tokens = float(CHUNK_SIZE)
        self.updated = time.monotonic()

    def consume(self, size):
        if self.rate == 0:
            return
        # 全接続で同じバケットを使う。
        with self.lock:
            while True:
                now = time.monotonic()
                self.tokens = min(CHUNK_SIZE, self.tokens + (now - self.updated) * self.rate)
                self.updated = now
                if self.tokens >= size:
                    self.tokens -= size
                    return
                time.sleep((size - self.tokens) / self.rate)


class BenchServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, directory, mbps):
        self.directory = directory
        self.limiter = BandwidthLimiter(mbps)
        self.gzip_cache = {}
        self.cache_lock = threading.Lock()
        self.log_lock = threading.Lock()
        super().__init__(address, BenchHandler)

    def compressed(self, path, stat):
        key = (path, stat.st_mtime_ns, stat.st_size)
        with self.cache_lock:
            if key not in self.gzip_cache:
                payload = gzip.compress(path.read_bytes(), compresslevel=6, mtime=0)
                # 更新前の同じファイルは保持しない。
                for old_key in list(self.gzip_cache):
                    if old_key[0] == path:
                        del self.gzip_cache[old_key]
                self.gzip_cache[key] = payload
            return self.gzip_cache[key]


class BenchHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._serve(False)

    def do_HEAD(self):
        self._serve(True)

    def log_message(self, format, *args):
        pass

    def _accepts_gzip(self):
        for entry in self.headers.get("Accept-Encoding", "").lower().split(","):
            parts = [part.strip() for part in entry.split(";")]
            if parts[0] != "gzip":
                continue
            quality = 1.0
            for parameter in parts[1:]:
                if parameter.startswith("q="):
                    try:
                        quality = float(parameter[2:])
                    except ValueError:
                        quality = 0.0
            if quality > 0:
                return True
        return False

    def _resolve_path(self):
        requested = unquote(urlsplit(self.path).path)
        path = (self.server.directory / requested.lstrip("/")).resolve()
        path.relative_to(self.server.directory)
        if path.is_dir():
            path = (path / "index.html").resolve()
            path.relative_to(self.server.directory)
        return path

    def _headers(self, status, content_type, size, compressed=False):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(size))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Vary", "Accept-Encoding")
        if compressed:
            self.send_header("Content-Encoding", "gzip")
        self.end_headers()

    def _write(self, chunk):
        self.server.limiter.consume(len(chunk))
        self.wfile.write(chunk)

    def _serve(self, head_only):
        started = time.monotonic()
        status = 404
        sent = 0
        source = None
        try:
            try:
                path = self._resolve_path()
                stat = path.stat()
                if not path.is_file():
                    raise FileNotFoundError
                content_type = CONTENT_TYPES.get(path.suffix.lower(), "application/octet-stream")
                compressed = self._accepts_gzip()
                if compressed:
                    payload = self.server.compressed(path, stat)
                    size = len(payload)
                else:
                    source = path.open("rb")
                    size = stat.st_size
                status = 200
            except (OSError, ValueError):
                payload = b"Not Found\n"
                compressed = self._accepts_gzip()
                if compressed:
                    payload = gzip.compress(payload, compresslevel=6, mtime=0)
                size = len(payload)
                content_type = "application/octet-stream"
            self._headers(status, content_type, size, compressed)
            if head_only:
                return
            if source is not None:
                while True:
                    chunk = source.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    self._write(chunk)
                    sent += len(chunk)
            else:
                for offset in range(0, size, CHUNK_SIZE):
                    chunk = payload[offset:offset + CHUNK_SIZE]
                    self._write(chunk)
                    sent += len(chunk)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass
        finally:
            if source is not None:
                source.close()
            elapsed = time.monotonic() - started
            with self.server.log_lock:
                print(f"{self.path!r} {status} {sent} {elapsed:.3f}s", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", required=True, type=Path)
    parser.add_argument("--port", type=int, default=8770)
    parser.add_argument("--mbps", type=float, default=0)
    args = parser.parse_args()
    if not math.isfinite(args.mbps) or args.mbps < 0:
        parser.error("--mbps must be a finite number >= 0")
    if not 0 <= args.port <= 65535:
        parser.error("--port must be between 0 and 65535")
    directory = args.dir.resolve()
    if not directory.is_dir():
        parser.error("--dir must be an existing directory")
    with BenchServer(("127.0.0.1", args.port), directory, args.mbps) as server:
        print(f"serving {directory} on http://127.0.0.1:{server.server_port} (mbps={args.mbps:g})", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
