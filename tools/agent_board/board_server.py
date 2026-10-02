"""PetLoop agent control board.

A tiny local server (standard library only) that shows what each feature
agent is doing. It combines two sources:

* what the agent says: state/status/<agent>.json, written by the agent;
* what git says: commits on the agent's branch, files changed, dirty files.

It also stores notes for an agent in state/inbox/<agent>.json, which the
agent reads before each milestone.

Run:  py -3 tools/agent_board/board_server.py [port]
Then open http://127.0.0.1:8095/
"""

from __future__ import annotations

import json
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
STATE = HERE / "state"
STATUS_DIR = STATE / "status"
INBOX_DIR = STATE / "inbox"
PROPOSALS_DIR = STATE / "proposals"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8095
GIT_TTL_SECONDS = 20
STATE_TTL_SECONDS = 4
MAX_NOTE_CHARS = 2000

_lock = threading.Lock()
_state_lock = threading.Lock()
_state_cache: dict = {"time": 0.0, "value": None}
_git_cache: dict[str, tuple[float, dict]] = {}
_last_good_status: dict[str, dict] = {}


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _git(args: list[str], cwd: Path) -> str | None:
    """Runs git and returns stdout, or None if it fails."""
    try:
        flags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        out = subprocess.run(
            ["git", *args], cwd=str(cwd), capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=30, creationflags=flags,
        )
        return out.stdout if out.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def _read_json(path: Path, fallback):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return fallback


def _roster() -> dict:
    return _read_json(HERE / "agents.json", {"agents": [], "lead": None, "mainBranch": "main"})


def _status(agent_id: str) -> dict | None:
    """The agent's own status file. A half-written file keeps the last good copy."""
    path = STATUS_DIR / f"{agent_id}.json"
    if not path.exists():
        return _last_good_status.get(agent_id)
    data = _read_json(path, None)
    if isinstance(data, dict):
        _last_good_status[agent_id] = data
    return _last_good_status.get(agent_id)


def _inbox(agent_id: str) -> list:
    data = _read_json(INBOX_DIR / f"{agent_id}.json", [])
    return data if isinstance(data, list) else []


def _git_facts(branch: str, worktree: str, main: str) -> dict:
    key = f"{branch}|{worktree}"
    cached = _git_cache.get(key)
    if cached and time.time() - cached[0] < GIT_TTL_SECONDS:
        return cached[1]

    facts: dict = {"branchExists": False, "worktreeExists": Path(worktree).is_dir()}
    if _git(["rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"], REPO) is not None:
        facts["branchExists"] = True
        ahead = _git(["rev-list", "--count", f"{main}..{branch}"], REPO)
        facts["ahead"] = int(ahead.strip()) if ahead and ahead.strip().isdigit() else 0
        log = _git(["log", f"{main}..{branch}", "-n", "6", "--format=%h%x1f%s%x1f%cI"], REPO) or ""
        commits = []
        for line in log.splitlines():
            parts = line.split("\x1f")
            if len(parts) == 3:
                commits.append({"hash": parts[0], "subject": parts[1], "when": parts[2]})
        facts["commits"] = commits
        stat = _git(["diff", "--shortstat", f"{main}...{branch}"], REPO) or ""
        files = ins = dels = 0
        for chunk in stat.split(","):
            chunk = chunk.strip()
            if not chunk:
                continue
            number = chunk.split(" ", 1)[0]
            if not number.isdigit():
                continue
            if "file" in chunk:
                files = int(number)
            elif "insertion" in chunk:
                ins = int(number)
            elif "deletion" in chunk:
                dels = int(number)
        facts.update({"filesChanged": files, "insertions": ins, "deletions": dels})
    if facts["worktreeExists"]:
        dirty = _git(["status", "--porcelain"], Path(worktree))
        if dirty is not None:
            facts["dirty"] = len([l for l in dirty.splitlines() if l.strip()])

    # A git command that timed out on a busy machine must not make a branch
    # look as if it vanished: keep the last good answer in that case.
    if not facts["branchExists"] and cached and cached[1].get("branchExists"):
        facts = cached[1]
    _git_cache[key] = (time.time(), facts)
    return facts


def _proposal_info(agent_id: str) -> dict:
    """Whether the agent has written its design proposal and mockup."""
    folder = PROPOSALS_DIR / agent_id
    doc, mockup = folder / "proposal.md", folder / "mockup.html"
    info: dict = {"hasDoc": doc.is_file(), "hasMockup": mockup.is_file()}
    times = [p.stat().st_mtime for p in (doc, mockup) if p.is_file()]
    if times:
        info["updated"] = datetime.fromtimestamp(max(times), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return info


def _known_agent(agent_id: str) -> bool:
    roster = _roster()
    ids = {a["id"] for a in roster.get("agents", [])}
    if roster.get("lead"):
        ids.add(roster["lead"]["id"])  # the lead can publish proposals too
    return agent_id in ids


def cached_state() -> dict:
    """The board state, computed by at most one request at a time.

    The page polls every few seconds and each computation runs a dozen git
    commands. On a busy machine those can take longer than the polling
    interval, so without this the requests pile up and never finish.
    """
    now = time.time()
    value = _state_cache["value"]
    if value is not None and now - _state_cache["time"] < STATE_TTL_SECONDS:
        return value
    if not _state_lock.acquire(blocking=value is None):
        return value  # someone else is refreshing: serve the last state
    try:
        value = _state_cache["value"]
        if value is None or time.time() - _state_cache["time"] >= STATE_TTL_SECONDS:
            value = build_state()
            _state_cache["value"] = value
            _state_cache["time"] = time.time()
        return value
    finally:
        _state_lock.release()


def build_state() -> dict:
    roster = _roster()
    main = roster.get("mainBranch", "main")
    head = (_git(["log", "-1", "--format=%h%x1f%s%x1f%cI", main], REPO) or "").strip().split("\x1f")
    agents = []
    for agent in roster.get("agents", []):
        status = _status(agent["id"])
        acked = set((status or {}).get("acked") or [])
        replies = (status or {}).get("replies") or {}
        notes = []
        for note in _inbox(agent["id"]):
            if not isinstance(note, dict):
                continue
            nid = str(note.get("id", ""))
            notes.append({
                "id": nid, "time": note.get("time"), "text": str(note.get("text", "")),
                "acked": nid in acked, "reply": replies.get(nid) if isinstance(replies, dict) else None,
            })
        agents.append({
            **agent,
            "status": status,
            "git": _git_facts(agent["branch"], agent["worktree"], main),
            "notes": notes,
            "proposal": _proposal_info(agent["id"]),
        })
    lead = roster.get("lead")
    if lead:
        lead = {**lead, "status": _status(lead["id"]), "proposal": _proposal_info(lead["id"])}
    return {
        "now": _now_iso(),
        "project": roster.get("project", ""),
        "main": {"hash": head[0], "subject": head[1], "when": head[2]} if len(head) == 3 else None,
        "lead": lead,
        "agents": agents,
    }


def add_note(agent_id: str, text: str) -> dict:
    roster = _roster()
    if agent_id not in {a["id"] for a in roster.get("agents", [])}:
        raise ValueError("Unknown agent.")
    text = text.strip()
    if not text:
        raise ValueError("The note is empty.")
    if len(text) > MAX_NOTE_CHARS:
        raise ValueError(f"Keep notes under {MAX_NOTE_CHARS} characters.")
    with _lock:
        INBOX_DIR.mkdir(parents=True, exist_ok=True)
        path = INBOX_DIR / f"{agent_id}.json"
        notes = _inbox(agent_id)
        note = {"id": f"n{len(notes) + 1}", "time": _now_iso(), "text": text}
        notes.append(note)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(notes, indent=2, ensure_ascii=False), encoding="utf-8")
        tmp.replace(path)
    return note


class Handler(BaseHTTPRequestHandler):
    server_version = "AgentBoard/1.0"

    def log_message(self, fmt, *args):  # keep the console quiet
        pass

    def _send(self, code: int, body: bytes, content_type: str, extra: dict | None = None):
        self.send_response(code)
        for name, value in (extra or {}).items():
            self.send_header(name, value)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code: int, payload):
        self._send(code, json.dumps(payload).encode("utf-8"), "application/json; charset=utf-8")

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            try:
                self._send(200, (HERE / "index.html").read_bytes(), "text/html; charset=utf-8")
            except OSError:
                self._send(500, b"index.html is missing", "text/plain; charset=utf-8")
        elif path == "/api/state":
            self._json(200, cached_state())
        elif path.startswith("/api/proposal/"):
            agent_id = path.rsplit("/", 1)[-1]
            if not _known_agent(agent_id):
                self._json(404, {"error": "Unknown agent."})
                return
            doc = PROPOSALS_DIR / agent_id / "proposal.md"
            try:
                text = doc.read_text(encoding="utf-8", errors="replace")
            except OSError:
                text = ""
            self._json(200, {"markdown": text, **_proposal_info(agent_id)})
        elif path.startswith("/mockup/"):
            agent_id = path.rsplit("/", 1)[-1]
            mockup = PROPOSALS_DIR / agent_id / "mockup.html"
            if not _known_agent(agent_id) or not mockup.is_file():
                self._send(404, b"No mockup yet.", "text/plain; charset=utf-8")
                return
            # Agent-written HTML: serve it sandboxed so it can run no script
            # and load nothing from the network or from this server.
            self._send(200, mockup.read_bytes(), "text/html; charset=utf-8", {
                "Content-Security-Policy":
                    "sandbox; default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:",
            })
        else:
            self._send(404, b"Not found", "text/plain; charset=utf-8")

    def do_POST(self):
        if self.path != "/api/note":
            self._send(404, b"Not found", "text/plain; charset=utf-8")
            return
        # Notes steer an agent, so only this page may post them: a custom
        # header cannot be sent cross-site without a CORS preflight, which
        # this server never grants.
        if self.headers.get("X-Agent-Board") != "1":
            self._json(403, {"error": "Forbidden."})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 64_000:
                raise ValueError("Too large.")
            data = json.loads(self.rfile.read(length).decode("utf-8"))
            note = add_note(str(data.get("agent", "")), str(data.get("text", "")))
            self._json(200, {"ok": True, "note": note})
        except ValueError as e:
            self._json(400, {"error": str(e)})


def main():
    STATUS_DIR.mkdir(parents=True, exist_ok=True)
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    PROPOSALS_DIR.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Agent control board: http://127.0.0.1:{PORT}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
