#!/usr/bin/env python3
"""
QualityAirApp Load Generator & Stress Testing Tool
=================================================
Injects concurrent HTTP requests into QualityAirApp to test load handling,
GCP Cloud Load Balancer distribution, and Compute Engine MIG autoscaling.

Features:
- Zero external dependencies required (uses standard library; optimizes with 'requests' if present)
- Configurable concurrency (threads), duration, or total request count
- Multiple traffic modes: mixed (realistic blend), stress-fast (/health only), cities, ui
- Real-time terminal dashboard updated every second (RPS, status codes, latency percentiles)
- Comprehensive summary report upon completion or Ctrl+C interruption

Usage Examples:
  # Quick 30s test against GCP Load Balancer with 10 concurrent workers
  python3 load_generator.py --url "$TARGET_URL" -c 10 -d 30

  # High-throughput CPU stress test on /health to trigger MIG autoscaling
  python3 load_generator.py --url "$TARGET_URL" -c 30 -d 120 --mode stress-fast

  # Local test against development server
  python3 load_generator.py --url http://localhost:8080 -c 5 -d 20
"""

import argparse
import itertools
import math
import os
import random
import sys
import threading
import time
from collections import Counter
from datetime import datetime

# Optional requests library for HTTP keep-alive connection pooling
try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False
    import urllib.error
    import urllib.parse
    import urllib.request


DEFAULT_TARGET_URL = os.environ.get("TARGET_URL", "http://localhost:8080")

SAMPLE_CITIES = [
    "Nairobi", "New York", "Paris", "London", "Tokyo",
    "Berlin", "Madrid", "Rome", "Sydney", "Cairo",
    "Dubai", "Mumbai", "Sao Paulo", "Los Angeles", "Toronto"
]


class LoadTestStats:
    """Thread-safe collector for request execution metrics."""

    def __init__(self):
        self._lock = threading.Lock()
        self.start_time = time.time()
        self.total_requests = 0
        self.status_codes = Counter()
        self.errors = Counter()
        self.latencies = []
        self.recent_latencies = []
        self.last_interval_reqs = 0
        self.last_interval_time = self.start_time

    def record_success(self, status_code: int, latency_ms: float):
        with self._lock:
            self.total_requests += 1
            self.status_codes[status_code] += 1
            self.latencies.append(latency_ms)
            self.recent_latencies.append(latency_ms)

    def record_error(self, error_type: str, latency_ms: float = 0.0):
        with self._lock:
            self.total_requests += 1
            self.errors[error_type] += 1
            if latency_ms > 0:
                self.latencies.append(latency_ms)
                self.recent_latencies.append(latency_ms)

    def snapshot_interval(self):
        with self._lock:
            now = time.time()
            elapsed_interval = max(now - self.last_interval_time, 0.001)
            delta_reqs = self.total_requests - self.last_interval_reqs
            current_rps = delta_reqs / elapsed_interval

            self.last_interval_reqs = self.total_requests
            self.last_interval_time = now

            recent = list(self.recent_latencies)
            self.recent_latencies.clear()

            total_elapsed = max(now - self.start_time, 0.001)
            avg_rps = self.total_requests / total_elapsed

            return {
                "elapsed": total_elapsed,
                "total_requests": self.total_requests,
                "current_rps": current_rps,
                "avg_rps": avg_rps,
                "status_codes": dict(self.status_codes),
                "errors": dict(self.errors),
                "recent_latencies": recent,
            }

    def get_final_stats(self):
        with self._lock:
            total_elapsed = max(time.time() - self.start_time, 0.001)
            return {
                "duration": total_elapsed,
                "total_requests": self.total_requests,
                "avg_rps": self.total_requests / total_elapsed,
                "status_codes": dict(self.status_codes),
                "errors": dict(self.errors),
                "latencies": list(self.latencies),
            }


def calculate_percentiles(latencies):
    if not latencies:
        return {"min": 0, "avg": 0, "p50": 0, "p90": 0, "p95": 0, "p99": 0, "max": 0}
    s = sorted(latencies)
    n = len(s)

    def percentile(p):
        k = (n - 1) * (p / 100.0)
        f = math.floor(k)
        c = math.ceil(k)
        if f == c:
            return s[int(k)]
        d0 = s[int(f)] * (c - k)
        d1 = s[int(c)] * (k - f)
        return d0 + d1

    return {
        "min": s[0],
        "avg": sum(s) / n,
        "p50": percentile(50),
        "p90": percentile(90),
        "p95": percentile(95),
        "p99": percentile(99),
        "max": s[-1],
    }


def pick_endpoint(mode: str, custom_endpoint: str = None) -> str:
    """Determine the next endpoint path based on the chosen mode."""
    if custom_endpoint:
        return custom_endpoint

    if mode == "stress-fast":
        return "/health"
    elif mode == "cities":
        city = random.choice(SAMPLE_CITIES)
        return f"/api/city?name={city}"
    elif mode == "ui":
        return "/"
    elif mode == "api":
        return "/api/air-quality"
    else:  # 'mixed' mode: realistic traffic distribution
        r = random.random()
        if r < 0.40:
            return "/health"
        elif r < 0.75:
            city = random.choice(SAMPLE_CITIES)
            return f"/api/city?name={city}"
        elif r < 0.90:
            return "/"
        else:
            return "/api/air-quality"


def http_worker(
    worker_id: int,
    base_url: str,
    mode: str,
    custom_endpoint: str,
    stats: LoadTestStats,
    stop_event: threading.Event,
    max_requests: int,
    request_counter: itertools.count,
    delay_s: float,
    timeout_s: float,
):
    """Worker thread running continuous HTTP requests."""
    # Ensure no trailing slash on base_url
    base = base_url.rstrip("/")

    # Setup session if requests is available for keep-alive performance
    session = requests.Session() if HAS_REQUESTS else None

    while not stop_event.is_set():
        if max_requests > 0:
            current_num = next(request_counter)
            if current_num >= max_requests:
                stop_event.set()
                break

        endpoint = pick_endpoint(mode, custom_endpoint)
        url = f"{base}{endpoint}"

        start_req = time.perf_counter()
        try:
            if HAS_REQUESTS:
                resp = session.get(url, timeout=timeout_s)
                latency_ms = (time.perf_counter() - start_req) * 1000.0
                stats.record_success(resp.status_code, latency_ms)
            else:
                req = urllib.request.Request(
                    url,
                    headers={"User-Agent": f"QualityAir-LoadTester/1.0 (Worker-{worker_id})"}
                )
                with urllib.request.urlopen(req, timeout=timeout_s) as resp:
                    latency_ms = (time.perf_counter() - start_req) * 1000.0
                    stats.record_success(resp.status, latency_ms)
        except Exception as exc:
            latency_ms = (time.perf_counter() - start_req) * 1000.0
            err_name = type(exc).__name__
            if hasattr(exc, "code"):  # HTTPError in urllib
                stats.record_success(exc.code, latency_ms)
            else:
                stats.record_error(err_name, latency_ms)

        if delay_s > 0 and not stop_event.is_set():
            time.sleep(delay_s)

    if session:
        session.close()


def display_monitor(
    stats: LoadTestStats,
    stop_event: threading.Event,
    target_url: str,
    concurrency: int,
    mode: str,
    duration_s: int,
    max_requests: int,
):
    """Background monitor displaying live throughput and latency stats."""
    terminal_clear = "\033[H\033[J"
    is_tty = sys.stdout.isatty()

    while not stop_event.wait(timeout=1.0):
        snap = stats.snapshot_interval()
        elapsed = snap["elapsed"]
        current_rps = snap["current_rps"]
        avg_rps = snap["avg_rps"]
        total = snap["total_requests"]

        # Latency on recent batch
        recent_p = calculate_percentiles(snap["recent_latencies"])

        # Remaining indicator
        if duration_s > 0:
            remaining = max(0, duration_s - int(elapsed))
            progress_str = f"Time: {int(elapsed)}s / {duration_s}s (Remaining: {remaining}s)"
        elif max_requests > 0:
            progress_str = f"Requests: {total} / {max_requests} ({total/max_requests*100:.1f}%)"
        else:
            progress_str = f"Time: {int(elapsed)}s (Running indefinitely, press Ctrl+C to stop)"

        # HTTP status code summary
        status_items = [f"{k}: {v}" for k, v in sorted(snap["status_codes"].items())]
        status_line = " | ".join(status_items) if status_items else "Awaiting responses..."

        # Error summary
        err_items = [f"{k}: {v}" for k, v in sorted(snap["errors"].items())]
        err_line = f"Errors: {' | '.join(err_items)}" if err_items else "Errors: 0"

        output = [
            "=" * 70,
            f" 🌍 QualityAirApp Load Generator | Engine: {'requests (Keep-Alive)' if HAS_REQUESTS else 'urllib'}",
            "=" * 70,
            f"Target URL:    {target_url}",
            f"Mode:          {mode.upper()}",
            f"Concurrency:   {concurrency} worker threads",
            f"Progress:      {progress_str}",
            "-" * 70,
            f"Throughput:    Current: {current_rps:7.1f} req/s  |  Average: {avg_rps:7.1f} req/s",
            f"Total Sent:    {total} requests",
            f"HTTP Status:   {status_line}",
            f"Health:        {err_line}",
            "-" * 70,
            "Latency (Recent 1s window):",
            f"  Min: {recent_p['min']:6.1f}ms | Avg: {recent_p['avg']:6.1f}ms | P50: {recent_p['p50']:6.1f}ms",
            f"  P90: {recent_p['p90']:6.1f}ms | P95: {recent_p['p95']:6.1f}ms | Max: {recent_p['max']:6.1f}ms",
            "=" * 70,
            "Press [Ctrl+C] to stop and generate final report.",
        ]

        if is_tty:
            sys.stdout.write(terminal_clear + "\n".join(output) + "\n")
            sys.stdout.flush()
        else:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Total: {total:5d} | "
                  f"Cur RPS: {current_rps:5.1f} | Avg RPS: {avg_rps:5.1f} | "
                  f"Avg Lat: {recent_p['avg']:5.1f}ms | Codes: {status_line}")


def print_final_report(stats: LoadTestStats, target_url: str, concurrency: int, mode: str):
    """Print the final comprehensive summary report after test completion."""
    data = stats.get_final_stats()
    p = calculate_percentiles(data["latencies"])

    print("\n" + "=" * 70)
    print(" 🏁 LOAD TEST COMPLETED - FINAL REPORT")
    print("=" * 70)
    print(f" Target URL:        {target_url}")
    print(f" Test Mode:         {mode}")
    print(f" Concurrency:       {concurrency} workers")
    print(f" Total Duration:    {data['duration']:.2f} seconds")
    print(f" Total Requests:    {data['total_requests']}")
    print(f" Average RPS:       {data['avg_rps']:.2f} requests/sec")
    print("-" * 70)
    print(" HTTP Status Breakdown:")
    total_reqs = max(data["total_requests"], 1)
    if data["status_codes"]:
        for code, count in sorted(data["status_codes"].items()):
            pct = (count / total_reqs) * 100
            print(f"   HTTP {code}: {count:7d} ({pct:5.1f}%)")
    else:
        print("   None recorded")

    if data["errors"]:
        print(" Network / Connection Errors:")
        for err, count in sorted(data["errors"].items()):
            pct = (count / total_reqs) * 100
            print(f"   {err}: {count:7d} ({pct:5.1f}%)")
    else:
        print(" Network / Connection Errors: 0")

    print("-" * 70)
    print(" Latency Distribution (end-to-end round trip):")
    print(f"   Min:     {p['min']:8.2f} ms")
    print(f"   Avg:     {p['avg']:8.2f} ms")
    print(f"   Median:  {p['p50']:8.2f} ms (p50)")
    print(f"   p90:     {p['p90']:8.2f} ms")
    print(f"   p95:     {p['p95']:8.2f} ms")
    print(f"   p99:     {p['p99']:8.2f} ms")
    print(f"   Max:     {p['max']:8.2f} ms")
    print("=" * 70 + "\n")


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Inject concurrent traffic into QualityAirApp to test GCP Load Balancer and autoscaling.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Export your Load Balancer IP dynamically or use a variable:
  export TARGET_URL="http://$(terraform -chdir=.. output -raw lb_ip_address)"

  # Quick 20-second test against GCP Load Balancer with 10 workers
  python3 load_generator.py -u "$TARGET_URL" -c 10 -d 20

  # High-throughput CPU stress test on /health to test autoscaling
  python3 load_generator.py -u "$TARGET_URL" -c 30 -d 60 --mode stress-fast

  # Test city search dynamic endpoints
  python3 load_generator.py -u "$TARGET_URL" -c 8 -d 30 --mode cities

  # Test local dev server
  python3 load_generator.py -u http://localhost:8080 -c 5 -d 15
        """
    )
    parser.add_argument(
        "-u", "--url",
        default=DEFAULT_TARGET_URL,
        help="Target QualityAir base URL (default: env $TARGET_URL or http://localhost:8080)"
    )
    parser.add_argument(
        "-c", "--concurrency",
        type=int,
        default=10,
        help="Number of concurrent worker threads (default: 10)"
    )
    parser.add_argument(
        "-d", "--duration",
        type=int,
        default=30,
        help="Duration of the test in seconds (default: 30, set 0 for indefinite)"
    )
    parser.add_argument(
        "-n", "--requests",
        type=int,
        default=0,
        help="Maximum total requests to send before stopping (default: 0 = unlimited)"
    )
    parser.add_argument(
        "-m", "--mode",
        choices=["mixed", "stress-fast", "cities", "ui", "api"],
        default="mixed",
        help="Traffic generation mode:\n"
             "  mixed:       Realistic mix of /health, /api/city, /, and /api/air-quality (default)\n"
             "  stress-fast: 100%% /health (high throughput, no external API latency, best for triggering MIG autoscaling)\n"
             "  cities:      100%% /api/city?name=<random city>\n"
             "  ui:          100%% HTML dashboard (/)\n"
             "  api:         100%% /api/air-quality\n"
    )
    parser.add_argument(
        "-e", "--endpoint",
        type=str,
        default=None,
        help="Custom endpoint path to test (e.g. /health or /api/city?name=Paris)"
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.0,
        help="Delay in seconds between requests per worker (default: 0.0 for max throughput)"
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="HTTP request timeout in seconds (default: 5.0)"
    )

    return parser.parse_args()


def main():
    args = parse_arguments()

    print("\n" + "=" * 70)
    print(" 🚀 Initializing QualityAir Load Injection")
    print("=" * 70)
    print(f" Target:       {args.url}")
    print(f" Concurrency:  {args.concurrency} workers")
    print(f" Mode:         {args.mode}")
    print(f" Duration:     {args.duration}s" if args.duration > 0 else " Duration:     Indefinite (Ctrl+C to stop)")
    if args.requests > 0:
        print(f" Max Reqs:     {args.requests}")
    print(f" Engine:       {'requests library' if HAS_REQUESTS else 'Python urllib (standard library)'}")
    print("=" * 70 + "\n")

    stats = LoadTestStats()
    stop_event = threading.Event()
    request_counter = itertools.count()

    # Launch worker threads
    workers = []
    for i in range(args.concurrency):
        t = threading.Thread(
            target=http_worker,
            args=(
                i + 1,
                args.url,
                args.mode,
                args.endpoint,
                stats,
                stop_event,
                args.requests,
                request_counter,
                args.delay,
                args.timeout,
            ),
            daemon=True
        )
        t.start()
        workers.append(t)

    # Launch monitor thread
    monitor_t = threading.Thread(
        target=display_monitor,
        args=(
            stats,
            stop_event,
            args.url,
            args.concurrency,
            args.mode,
            args.duration,
            args.requests,
        ),
        daemon=True
    )
    monitor_t.start()

    # Main execution loop timing
    start_time = time.time()
    try:
        while not stop_event.is_set():
            if args.duration > 0 and (time.time() - start_time) >= args.duration:
                stop_event.set()
                break
            time.sleep(0.2)
    except KeyboardInterrupt:
        print("\n\n⚠️ Interrupted by user (Ctrl+C). Gracefully stopping workers...")
        stop_event.set()

    # Wait briefly for workers to finish current in-flight request
    for t in workers:
        t.join(timeout=1.0)

    # Print final summary
    print_final_report(stats, args.url, args.concurrency, args.mode)


if __name__ == "__main__":
    main()

