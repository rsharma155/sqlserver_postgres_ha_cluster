#!/usr/bin/env python3
"""
SQL Server HA Load Test App

Runs 10 concurrent user sessions performing CRUD operations
across 5 databases on 3 SQL Server nodes.
"""

import argparse
import signal
import sys
import threading
import time
from datetime import datetime

from config import USERS, DEFAULT_DURATION_SECONDS, DEFAULT_MIN_DELAY, DEFAULT_MAX_DELAY
from users import USER_PROFILES, run_user_session, SHOW_SQL


def merge_user_configs():
    merged = []
    for p in USER_PROFILES:
        uname = p["username"]
        if uname in USERS:
            p["password"] = USERS[uname]["password"]
            p["node"] = USERS[uname]["node"]
        merged.append(p)
    return merged


def print_banner():
    print("=" * 64)
    print("  SQL Server HA — Load Test App")
    print("  10 concurrent users · 5 databases · 3 nodes")
    print("=" * 64)


def print_stats(results, duration, stopped_early=False):
    print()
    print("-" * 64)
    label = "  Results  (STOPPED EARLY)" if stopped_early else f"  Results  ({datetime.now().strftime('%H:%M:%S')})"
    print(label)
    print("-" * 64)
    print(f"  Runtime:             {duration:.1f}s")
    total_ops = sum(r["ops"] for r in results)
    total_err = sum(r.get("errors", 0) for r in results)
    total_rows = sum(r.get("rows", 0) for r in results)
    print(f"  Total operations:    {total_ops}")
    print(f"  Total rows affected: {total_rows}")
    print(f"  Total errors:        {total_err}")
    print()
    print(f"  {'User':<20} {'Label':<28} {'Ops':>6} {'Rows':>8} {'Err':>6}")
    print(f"  {'-'*20} {'-'*28} {'-'*6} {'-'*8} {'-'*6}")
    for r in results:
        err_str = r.get("error", str(r.get("errors", 0)))
        rows_str = str(r.get("rows", 0))
        print(f"  {r['user']:<20} {r['label']:<28} {r['ops']:>6} {rows_str:>8} {err_str:>6}")
    print("-" * 64)

    if total_ops > 0:
        print(f"  Throughput: {total_ops/duration:.2f} ops/sec")
    print()


def main():
    parser = argparse.ArgumentParser(description="SQL Server HA Load Test")
    parser.add_argument(
        "-d", "--duration", type=int, default=DEFAULT_DURATION_SECONDS,
        help=f"Test duration in seconds (default: {DEFAULT_DURATION_SECONDS})"
    )
    parser.add_argument(
        "--min-delay", type=float, default=DEFAULT_MIN_DELAY,
        help=f"Min delay between ops in seconds (default: {DEFAULT_MIN_DELAY})"
    )
    parser.add_argument(
        "--max-delay", type=float, default=DEFAULT_MAX_DELAY,
        help=f"Max delay between ops in seconds (default: {DEFAULT_MAX_DELAY})"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print user configuration and exit"
    )
    parser.add_argument(
        "--quiet", action="store_true",
        help="Suppress per-query SQL logging"
    )

    args = parser.parse_args()

    profiles = merge_user_configs()

    if args.dry_run:
        print_banner()
        print(f"  Duration:            {args.duration}s")
        print(f"  Delay range:         {args.min_delay}–{args.max_delay}s")
        print()
        for p in profiles:
            dbs = ", ".join(n for n, _ in p["db_ops"])
            print(f"  {p['username']:<18} -> {p['label']:<28} [{p['node']}] {dbs}")
        print()
        return

    if args.quiet:
        import users as users_mod
        users_mod.SHOW_SQL = False

    print_banner()
    print(f"  Duration:  {args.duration}s  |  Delay: {args.min_delay}–{args.max_delay}s")
    print("  Press Ctrl+C to stop early")
    print()

    results = []
    threads = []
    stop_event = threading.Event()

    # Install Ctrl+C handler — sets event directly (more reliable than KeyboardInterrupt on Windows)
    def on_ctrl_c(sig, frame):
        stop_event.set()
    signal.signal(signal.SIGINT, on_ctrl_c)

    start_barrier = threading.Barrier(len(profiles) + 1)

    def wrapped_run(profile):
        try:
            start_barrier.wait()
        except threading.BrokenBarrierError:
            return
        if not stop_event.is_set():
            run_user_session(profile, args.duration, args.min_delay, args.max_delay, results, stop_event)

    for profile in profiles:
        t = threading.Thread(target=wrapped_run, args=(profile,), daemon=True)
        threads.append(t)
        print(f"  Starting: {profile['username']:<18} ({profile['label']})")
        t.start()

    start_ts = None
    stopped_early = False

    # Wait for all threads to reach the starting barrier
    try:
        start_barrier.wait(timeout=30)
        start_ts = time.time()
    except threading.BrokenBarrierError:
        print("  Barrier broken during startup")
        stop_event.set()
        stopped_early = True

    if not start_ts:
        start_ts = time.time()

    # Poll threads with sleep() — set stop_event via signal handler on Ctrl+C
    while any(t.is_alive() for t in threads):
        if stop_event.is_set():
            stopped_early = True
            break
        time.sleep(0.3)

    if stop_event.is_set():
        # Wait for threads to finish their current op and record results (up to 9s)
        for _ in range(30):
            if not any(t.is_alive() for t in threads):
                break
            time.sleep(0.3)

    elapsed = time.time() - start_ts
    print_stats(results, elapsed, stopped_early)


if __name__ == "__main__":
    main()
