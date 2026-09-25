#!/usr/bin/env python3
"""Watch background builder agents and exit the moment one needs the orchestrator.

Run it with `run_in_background: true` while builders are out. It polls every agent worktree
under `<repo>/.claude/worktrees/agent-*` and exits with a report when any agent is:

  HUNG      a test JVM in its worktree has run longer than --max-test-min
  STALLED   its transcript has not changed for --stall-min (dead, or blocked in one tool call)
  OVERTIME  it has been running longer than --max-agent-min

The exit is what wakes the orchestrator: a finished background command sends a notification.
After acting on a flag, acknowledge it with --ack <id>:<kind> (repeatable) and start the
watchdog again, or it will report the same flag straight away. It also exits, quietly, once
no agent is left running. Pass --session with the orchestrator's session id (the directory
name in its scratchpad path) so agents from other sessions stay out of the report.
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import time

# A Gradle test executor runs with its worker tmpdir under the test task's build dir, which tells it
# apart from the long-lived worker daemons that other tasks keep around.
TEST_JVM = re.compile(r"org\.gradle\.internal\.worker\.tmpdir=\S*/build/tmp/\w*[Tt]est\w*/work")


def etime_seconds(etime):
    days, _, rest = etime.strip().rpartition("-")
    parts = [int(p) for p in rest.split(":")]
    while len(parts) < 3:
        parts.insert(0, 0)
    hours, minutes, seconds = parts
    return (int(days) if days else 0) * 86400 + hours * 3600 + minutes * 60 + seconds


def test_jvms():
    out = subprocess.run(["ps", "-eo", "pid=,etime=,command="], capture_output=True, text=True).stdout
    for line in out.splitlines():
        pid, etime, command = line.strip().split(None, 2)
        if TEST_JVM.search(command):
            yield int(pid), etime_seconds(etime), command


def stuck_frame(pid, command):
    """The first project frame under the test thread, from one thread dump."""
    java = command.split()[0]
    jstack = os.path.join(os.path.dirname(java), "jstack")
    if not os.path.exists(jstack):
        jstack = "jstack"
    try:
        dump = subprocess.run([jstack, str(pid)], capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.TimeoutExpired):
        return "no thread dump"
    in_test_thread = False
    for line in dump.splitlines():
        if line.startswith('"'):
            in_test_thread = line.startswith('"Test worker')
        elif in_test_thread and line.strip().startswith("at ") and not re.search(
            r"at (java|javax|jdk|sun|kotlin|kotlinx|androidx|org\.(junit|gradle|jetbrains))\.", line
        ):
            return line.strip()[3:]
    return "no project frame in the test thread"


def transcript_for(agent_id, session):
    pattern = f"~/.claude/projects/*/{session or '*'}/subagents/agent-{agent_id}.jsonl"
    paths = glob.glob(os.path.expanduser(pattern))
    return max(paths, key=os.path.getmtime) if paths else None


def stopped(transcript):
    try:
        with open(transcript[: -len(".jsonl")] + ".meta.json") as f:
            return bool(json.load(f).get("stoppedByUser"))
    except (OSError, ValueError):
        return False


def finished(transcript):
    """True when the agent's last assistant turn ended the run rather than calling a tool."""
    with open(transcript, "rb") as f:
        f.seek(0, os.SEEK_END)
        f.seek(max(0, f.tell() - 200_000))
        lines = f.read().decode("utf-8", "replace").splitlines()
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("type") == "assistant":
            return entry.get("message", {}).get("stop_reason") == "end_turn"
        if entry.get("type") == "user":
            return False
    return False


def scan(repo, args, acked):
    now = time.time()
    flags, live = [], 0
    jvms = list(test_jvms())
    for worktree in sorted(glob.glob(os.path.join(repo, ".claude", "worktrees", "agent-*"))):
        agent_id = os.path.basename(worktree)[len("agent-"):]
        transcript = transcript_for(agent_id, args.session)
        if not os.path.exists(os.path.join(worktree, ".git")) or not transcript:
            continue
        stat = os.stat(transcript)
        if (now - stat.st_mtime) / 3600 > args.forget_hours or stopped(transcript) or finished(transcript):
            continue
        live += 1
        started = getattr(stat, "st_birthtime", stat.st_ctime)
        age, quiet = (now - started) / 60, (now - stat.st_mtime) / 60
        found = []
        for pid, seconds, command in jvms:
            if worktree + "/" in command and seconds / 60 > args.max_test_min:
                found.append(("HUNG", f"test JVM {pid} running {seconds // 60} min, stuck at {stuck_frame(pid, command)}"))
        if quiet > args.stall_min:
            found.append(("STALLED", f"transcript unchanged for {quiet:.0f} min"))
        if age > args.max_agent_min:
            found.append(("OVERTIME", f"running {age:.0f} min"))
        for kind, detail in found:
            if f"{agent_id}:{kind}" not in acked:
                flags.append(f"{kind} agent {agent_id} ({worktree}): {detail}")
    for pid, seconds, command in jvms:
        if "/.claude/worktrees/" not in command and repo + "/" in command and seconds / 60 > args.max_test_min:
            if f"main:HUNG" not in acked:
                flags.append(f"HUNG main checkout: test JVM {pid} running {seconds // 60} min, stuck at {stuck_frame(pid, command)}")
    return flags, live


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", default=os.getcwd(), help="repository root that holds .claude/worktrees")
    parser.add_argument("--max-test-min", type=float, default=6, help="a test JVM older than this is hung")
    parser.add_argument("--stall-min", type=float, default=15, help="no transcript change for this long is a stall")
    parser.add_argument("--max-agent-min", type=float, default=60, help="an agent older than this is over time")
    parser.add_argument("--session", help="only watch agents spawned by this session id")
    parser.add_argument("--forget-hours", type=float, default=3, help="ignore agents untouched for this long")
    parser.add_argument("--poll", type=float, default=60, help="seconds between scans")
    parser.add_argument("--ack", action="append", default=[], help="<agent-id>:<KIND> or main:HUNG to ignore")
    parser.add_argument("--once", action="store_true", help="scan once, print, and exit")
    args = parser.parse_args()
    repo = os.path.realpath(args.repo)
    acked = set(args.ack)
    while True:
        flags, live = scan(repo, args, acked)
        if flags:
            print("watchdog: act on these, then restart with --ack for any you keep running")
            print("\n".join(flags))
            return 0
        if args.once or live == 0:
            print(f"watchdog: {live} agent(s) running, nothing to report")
            return 0
        time.sleep(args.poll)


if __name__ == "__main__":
    sys.exit(main())
