"""
Flask web application for the DB CRUD Load Generator.

Routes:
  GET  /                           — Environment selection page
  GET  /crud/<environment>         — CRUD configuration page
  POST /start_crud                 — Start a CRUD load test job
  GET  /job_status/<int:job_id>    — Poll job status and events
  GET  /job_report/<int:job_id>    — Download job report (text)
  POST /stop_job/<int:job_id>      — Stop a running job
  GET  /backup                     — Backup manager page
  GET  /backup/status              — Backup service status JSON
  POST /backup/start_pg            — Start PG WAL archiving
  POST /backup/stop_pg             — Stop PG WAL archiving
  POST /backup/start_mssql         — Start SQL Server TLOG backups
  POST /backup/stop_mssql          — Stop SQL Server TLOG backups
  GET  /activity                   — Recent command log entries (JSON)
  GET  /app_log                    — Recent application log entries (JSON)

Design:
  - CRUD jobs run in background daemon threads.
  - Each job has its own stop_event for graceful cancellation.
  - Status callbacks stream per-operation results back via polling.
  - The backup manager runs its own scheduler threads.
  - All system commands are recorded in the in-memory CommandLog
    and exposed via /activity for the live activity panel.
  - A rotating file logger keeps debug info in app.log.
  - After each CRUD run, a text report is generated for review
    and failed-task analysis.
"""

import os
import secrets
import threading
import json
import traceback
from collections import Counter
from datetime import datetime
from flask import Flask, render_template, request, jsonify, Response

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY") or secrets.token_hex(32)

import logging
logging.getLogger("werkzeug").setLevel(logging.WARNING)

from config import DATABASES, ACTIVE_ENVIRONMENTS, CRUD_LIMITS
from pg_runner import run_pg_crud
from sql_runner import run_sql_crud
from backup_manager import backup_manager
from command_log import command_log
from app_logger import logger, recent_logs

active_jobs = {}
REPORTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports")
os.makedirs(REPORTS_DIR, exist_ok=True)
job_id_counter = [0]
jobs_lock = threading.Lock()


@app.route("/")
def index():
    return render_template("index.html", databases=DATABASES, active_envs=ACTIVE_ENVIRONMENTS)


@app.route("/crud/<environment>")
def crud_config(environment):
    if environment not in ("postgres", "sqlserver"):
        return "Invalid environment", 400
    return render_template("crud_config.html", environment=environment, databases=DATABASES)


@app.route("/start_crud", methods=["POST"])
def start_crud():
    try:
        data = request.get_json()
        env = data.get("environment", "postgres")
        if env not in ("postgres", "sqlserver"):
            return jsonify({"error": "Invalid environment; must be 'postgres' or 'sqlserver'"}), 400
        seconds = int(data.get("seconds", CRUD_LIMITS["default_duration"]))
        threads = int(data.get("threads", CRUD_LIMITS["default_threads"]))
        users = int(data.get("users", CRUD_LIMITS["default_users"]))

        errors = []
        if seconds < 5 or seconds > CRUD_LIMITS["max_duration"]:
            errors.append(f"Duration must be 5–{CRUD_LIMITS['max_duration']}s")
        if threads < 1 or threads > CRUD_LIMITS["max_threads"]:
            errors.append(f"Worker threads must be 1–{CRUD_LIMITS['max_threads']}")
        if users < 1 or users > CRUD_LIMITS["max_users"]:
            errors.append(f"Concurrent users must be 1–{CRUD_LIMITS['max_users']}")
        if threads * users > CRUD_LIMITS["max_concurrency"]:
            errors.append(
                f"Total concurrency (threads × users = {threads * users}) "
                f"exceeds limit of {CRUD_LIMITS['max_concurrency']}. "
                f"Reduce threads or users."
            )
        if errors:
            return jsonify({"error": " | ".join(errors)}), 400

        logger.info("Starting CRUD job | env=%s seconds=%d threads=%d users=%d",
                     env, seconds, threads, users)
        command_log.add("System", f"Starting CRUD job: env={env}, duration={seconds}s, threads={threads}, users={users}")

        with jobs_lock:
            job_id_counter[0] += 1
            job_id = job_id_counter[0]

        stop_event = threading.Event()
        status_events = []

        def status_callback(s):
            status_events.append(s)

        def run_job():
            try:
                if env == "postgres":
                    result = run_pg_crud(
                        seconds=seconds, threads=threads, app_names=users,
                        status_callback=status_callback, stop_event=stop_event,
                    )
                else:
                    result = run_sql_crud(
                        seconds=seconds, threads=threads, users_per_thread=users,
                        status_callback=status_callback, stop_event=stop_event,
                    )

                with jobs_lock:
                    if job_id in active_jobs:
                        active_jobs[job_id]["result"] = result
                        active_jobs[job_id]["status"] = "completed"

                report_text = generate_report(job_id, env, data, result)
                report_path = os.path.join(REPORTS_DIR, f"crud_job_{job_id}.txt")
                with open(report_path, "w", encoding="utf-8") as f:
                    f.write(report_text)
                with jobs_lock:
                    if job_id in active_jobs:
                        active_jobs[job_id]["report_path"] = report_path

                logger.info("CRUD job %d completed: %d succeeded, %d failed",
                            job_id, result.get("total_succeeded", 0),
                            result.get("total_failed", 0))
                command_log.add("System", f"CRUD job {job_id} completed | "
                                f"succeeded={result.get('total_succeeded',0)} "
                                f"failed={result.get('total_failed',0)}")
            except Exception as exc:
                logger.error("CRUD job %d failed: %s", job_id, exc, exc_info=True)
                command_log.add("System", f"CRUD job {job_id} failed: {exc}")

        with jobs_lock:
            active_jobs[job_id] = {
                "id": job_id,
                "env": env,
                "seconds": seconds,
                "threads": threads,
                "users": users,
                "status": "running",
                "started": datetime.now().isoformat(),
                "events": status_events,
                "stop_event": stop_event,
                "result": None,
            }

        t = threading.Thread(target=run_job, daemon=True)
        t.start()

        return jsonify({"job_id": job_id})
    except Exception as exc:
        logger.error("start_crud failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


@app.route("/job_status/<int:job_id>")
def job_status(job_id):
    try:
        with jobs_lock:
            job = active_jobs.get(job_id)
            if not job:
                return jsonify({"error": "Job not found"}), 404

            recent_events = job["events"][-50:]
            return jsonify({
                "job_id": job_id,
                "status": job["status"],
                "env": job["env"],
                "seconds": job["seconds"],
                "threads": job["threads"],
                "users": job["users"],
                "started": job["started"],
                "recent_events": recent_events,
                "result": job["result"],
            })
    except Exception as exc:
        logger.error("job_status failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


@app.route("/stop_job/<int:job_id>", methods=["POST"])
def stop_job(job_id):
    try:
        with jobs_lock:
            job = active_jobs.get(job_id)
            if job and job["stop_event"]:
                job["stop_event"].set()
                logger.info("CRUD job %d stopped by user", job_id)
                command_log.add("System", f"CRUD job {job_id} stopped by user")
                return jsonify({"status": "stopped"})
        return jsonify({"error": "Job not found"}), 404
    except Exception as exc:
        logger.error("stop_job failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


# ── Report Generation ──────────────────────────────────────────

def generate_report(job_id, env, config, result):
    lines = []
    lines.append("=" * 72)
    lines.append(f"  CRUD Load Test Report — Job #{job_id}")
    lines.append("=" * 72)
    lines.append(f"")
    lines.append(f"  Environment:  {env}")
    lines.append(f"  Duration:     {config.get('seconds', '?')}s")
    lines.append(f"  Threads:      {config.get('threads', '?')}")
    lines.append(f"  Users:        {config.get('users', '?')}")
    lines.append(f"  Elapsed:      {result.get('elapsed', '?')}s")
    lines.append(f"  Started:      {active_jobs.get(job_id, {}).get('started', '?')}")
    lines.append(f"")
    lines.append("-" * 72)
    lines.append(f"  SUMMARY")
    lines.append("-" * 72)
    lines.append(f"  Total Attempted:  {result.get('total_attempted', 0)}")
    lines.append(f"  Total Succeeded:  {result.get('total_succeeded', 0)}")
    lines.append(f"  Total Failed:     {result.get('total_failed', 0)}")
    if result.get("total_attempted", 0) > 0:
        pct = result["total_succeeded"] / result["total_attempted"] * 100
        lines.append(f"  Success Rate:     {pct:.1f}%")
    lines.append(f"  Throughput:       {result.get('throughput', 0)} ops/sec")
    lines.append(f"")

    stats = result.get("stats", {})
    if stats:
        lines.append("-" * 72)
        lines.append(f"  PER-OPERATION STATS")
        lines.append("-" * 72)
        lines.append(f"  {'Database':<20} {'Op':<6} {'Attempted':>10} {'Succeeded':>10} {'Failed':>8} {'Rate':>7}")
        lines.append(f"  {'-'*20} {'-'*6} {'-'*10} {'-'*10} {'-'*8} {'-'*7}")
        for key in sorted(stats.keys()):
            db, op = key.split(".", 1) if "." in key else (key, "?")
            s = stats[key]
            rate = (s["succeeded"] / s["attempted"] * 100) if s["attempted"] > 0 else 0
            lines.append(f"  {db:<20} {op:<6} {s['attempted']:>10} {s['succeeded']:>10} {s['failed']:>8} {rate:>6.1f}%")
        lines.append(f"")

    failed_ops = result.get("failed_ops", [])
    if failed_ops:
        lines.append("-" * 72)
        lines.append(f"  FAILED TASK ANALYSIS  ({len(failed_ops)} total failures)")
        lines.append("-" * 72)

        error_counts = Counter(f.get("error", "Unknown") for f in failed_ops)
        lines.append(f"")
        lines.append(f"  Top Errors:")
        for err, count in error_counts.most_common(10):
            lines.append(f"    [{count:>4}x] {err}")

        db_counts = Counter(f.get("db", "?") for f in failed_ops)
        lines.append(f"")
        lines.append(f"  Failures by Database:")
        for db, count in db_counts.most_common():
            lines.append(f"    {db:<20} {count:>4}")

        op_counts = Counter(f.get("op", "?") for f in failed_ops)
        lines.append(f"")
        lines.append(f"  Failures by Operation:")
        for op, count in op_counts.most_common(15):
            lines.append(f"    {op:<45} {count:>4}")

        lines.append(f"")
        lines.append(f"  Recent Failed Tasks (last 20):")
        lines.append(f"  {'Time':<8} {'Database':<18} {'Operation':<30} {'Error':<45}")
        lines.append(f"  {'-'*8} {'-'*18} {'-'*30} {'-'*45}")
        for f in failed_ops[-20:]:
            err_short = f.get("error", "")[:44]
            op_short = f.get("op", "")[:29]
            lines.append(f"  {f.get('time',''):<8} {f.get('db',''):<18} {op_short:<30} {err_short:<45}")
    else:
        lines.append(f"  No failures recorded.")

    lines.append(f"")
    lines.append("=" * 72)
    lines.append(f"  End of Report — Job #{job_id}")
    lines.append("=" * 72)
    return "\n".join(lines)


@app.route("/job_report/<int:job_id>")
def job_report(job_id):
    try:
        with jobs_lock:
            job = active_jobs.get(job_id)
            if not job:
                return jsonify({"error": "Job not found"}), 404
            report_path = job.get("report_path")

        if report_path and os.path.exists(report_path):
            with open(report_path, "r", encoding="utf-8") as f:
                text = f.read()
        else:
            result = job.get("result")
            if not result:
                return jsonify({"error": "Report not yet available"}), 400
            env = job.get("env", "?")
            config = {"seconds": job.get("seconds"), "threads": job.get("threads"), "users": job.get("users")}
            text = generate_report(job_id, env, config, result)

        return Response(
            text,
            mimetype="text/plain",
            headers={"Content-Disposition": f"attachment; filename=crud_job_{job_id}.txt"},
        )
    except Exception as exc:
        logger.error("job_report failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


# ── Activity & Log endpoints ───────────────────────────────────

@app.route("/activity")
def activity():
    """Return the most recent command-log entries for the UI panel."""
    try:
        n = request.args.get("n", 50, type=int)
        return jsonify(command_log.recent(n))
    except Exception as exc:
        logger.error("activity endpoint failed: %s", exc, exc_info=True)
        return jsonify([])


@app.route("/app_log")
def app_log():
    """Return recent application log lines for debugging."""
    try:
        n = request.args.get("n", 50, type=int)
        return jsonify(recent_logs(n))
    except Exception as exc:
        logger.error("app_log endpoint failed: %s", exc, exc_info=True)
        return jsonify([])


# ── Backup endpoints ───────────────────────────────────────────

@app.route("/backup")
def backup_page():
    try:
        status = backup_manager.get_status()
        return render_template("backup.html", status=status)
    except Exception as exc:
        logger.error("backup_page failed: %s", exc, exc_info=True)
        return "Internal error", 500


@app.route("/backup/status")
def backup_status():
    try:
        return jsonify(backup_manager.get_status())
    except Exception as exc:
        logger.error("backup_status failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


@app.route("/backup/start_pg", methods=["POST"])
def start_pg_backup():
    try:
        data = request.get_json() or {}
        interval = int(data.get("interval", 300))
        fake = data.get("fake", False)
        backup_manager.start_pg_archive(interval, fake=fake)
        logger.info("PG WAL archiving started | interval=%ds fake=%s", interval, fake)
        command_log.add("System", f"PG WAL archiving started (interval={interval}s, fake={fake})")
        return jsonify({"status": "started", "interval": interval, "fake": fake})
    except Exception as exc:
        logger.error("start_pg_backup failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


@app.route("/backup/stop_pg", methods=["POST"])
def stop_pg_backup():
    try:
        backup_manager.stop_pg_archive()
        logger.info("PG WAL archiving stopped")
        command_log.add("System", "PG WAL archiving stopped")
        return jsonify({"status": "stopped"})
    except Exception as exc:
        logger.error("stop_pg_backup failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


@app.route("/backup/start_mssql", methods=["POST"])
def start_mssql_backup():
    try:
        data = request.get_json() or {}
        interval = int(data.get("interval", 300))
        fake = data.get("fake", False)
        backup_manager.start_mssql_backup(interval, fake=fake)
        logger.info("MSSQL TLOG backup started | interval=%ds fake=%s", interval, fake)
        command_log.add("System", f"MSSQL TLOG backup started (interval={interval}s, fake={fake})")
        return jsonify({"status": "started", "interval": interval, "fake": fake})
    except Exception as exc:
        logger.error("start_mssql_backup failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


@app.route("/backup/stop_mssql", methods=["POST"])
def stop_mssql_backup():
    try:
        backup_manager.stop_mssql_backup()
        logger.info("MSSQL TLOG backup stopped")
        command_log.add("System", "MSSQL TLOG backup stopped")
        return jsonify({"status": "stopped"})
    except Exception as exc:
        logger.error("stop_mssql_backup failed: %s", exc, exc_info=True)
        return jsonify({"error": str(exc)}), 500


# ── Error handler ──────────────────────────────────────────────

@app.errorhandler(500)
def handle_500(e):
    logger.error("Unhandled 500: %s", e, exc_info=True)
    return jsonify({"error": "Internal server error"}), 500


@app.errorhandler(404)
def handle_404(e):
    return jsonify({"error": "Not found"}), 404


if __name__ == "__main__":
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    logger.info("Starting DB CRUD web app on http://0.0.0.0:5002 (debug=%s)", debug)
    app.run(host="0.0.0.0", port=5002, debug=debug)
