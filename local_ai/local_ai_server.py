#!/usr/bin/env python3
"""
Small localhost AI bridge for Forever Space.

The default backend is an echo stub so Orbit can be wired and exported without
choosing a local model yet. Add a model backend by implementing LocalAIBackend
and registering it in BACKENDS.
"""

from __future__ import annotations

import argparse
import atexit
import importlib.util
import json
import os
import shutil
import subprocess
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, Optional, Type
import urllib.error
import urllib.request
from urllib.parse import urlparse


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
DEFAULT_LLAMA_SERVER_PORT = 8767
MAX_BODY_BYTES = 1024 * 1024
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
LLAMA_SERVER_EXECUTABLE_NAMES = (
    "llama-server",
    "llama-server.exe",
    "server",
    "server.exe",
)
LLAMA_EXECUTABLE_NAMES = (
    "llama-cli",
    "llama-cli.exe",
    "llama-server",
    "llama-server.exe",
    "main.exe",
)


def resolve_project_path(path_text: str) -> Path:
    raw_path = str(path_text or "").strip()
    if raw_path.startswith("res://"):
        return (PROJECT_ROOT / raw_path.replace("res://", "", 1)).resolve()

    path = Path(raw_path)
    if path.is_absolute():
        return path

    candidates = [
        Path.cwd() / path,
        PROJECT_ROOT / path,
        SCRIPT_DIR / path,
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()

    return candidates[0].resolve()


def resolve_model_path(model_id: str) -> Path:
    raw_path = str(model_id or "").strip()
    if raw_path == "":
        return PROJECT_ROOT / ""

    return resolve_project_path(raw_path)


def find_llama_executables() -> list[str]:
    found: list[str] = []
    seen: set[str] = set()

    def add_path(path_text: str) -> None:
        clean = str(path_text or "").strip()
        if clean == "":
            return
        if Path(clean).name.lower() not in [name.lower() for name in LLAMA_EXECUTABLE_NAMES]:
            return
        normalized = str(Path(clean).resolve())
        if normalized in seen:
            return
        seen.add(normalized)
        found.append(normalized)

    for exe_name in LLAMA_EXECUTABLE_NAMES:
        path = shutil.which(exe_name)
        if path:
            add_path(path)

    local_roots = [
        SCRIPT_DIR / "runtime",
        PROJECT_ROOT / "local_ai" / "runtime",
        PROJECT_ROOT / "runtime",
        PROJECT_ROOT / "bin",
        SCRIPT_DIR,
    ]
    for root in local_roots:
        for exe_name in LLAMA_EXECUTABLE_NAMES:
            candidate = root / exe_name
            if candidate.exists():
                add_path(str(candidate))

    return found


def find_llama_server_executables() -> list[str]:
    executables = []
    for path_text in find_llama_executables():
        if Path(path_text).name.lower() in [name.lower() for name in LLAMA_SERVER_EXECUTABLE_NAMES]:
            executables.append(path_text)
    return executables


def resolve_llama_server_path(path_text: str = "") -> Optional[Path]:
    clean_path = str(path_text or "").strip()
    if clean_path != "":
        candidate = resolve_project_path(clean_path)
        if candidate.exists():
            return candidate
        return None

    executables = find_llama_server_executables()
    if executables:
        return Path(executables[0]).resolve()
    return None


def build_plain_prompt(packet: Dict[str, Any]) -> str:
    history = packet.get("history", [])
    message = str(packet.get("message", "")).strip()
    lines = [
        "You are the local AI for Forever Space.",
        "Answer naturally and do not repeat the user's text unless it is useful.",
        "",
    ]

    if isinstance(history, list):
        for item in history[-8:]:
            if not isinstance(item, dict):
                continue
            role = str(item.get("role", "user")).strip().lower()
            content = str(item.get("content", "")).strip()
            if content == "":
                continue
            label = "AI" if role in ["assistant", "ai"] else "USER"
            lines.append(f"{label}: {content}")

    lines.append(f"USER: {message}")
    lines.append("AI:")
    return "\n".join(lines)


def parse_intish(value: Any) -> int:
    try:
        return int(float(str(value)))
    except Exception as exc:
        raise argparse.ArgumentTypeError(f"expected an integer value, got {value!r}") from exc


def build_chat_messages(packet: Dict[str, Any]) -> list[Dict[str, str]]:
    system_prompt = [
        "You are the local AI for Forever Space.",
        "Answer naturally, stay concise, and do not repeat the user's text unless it is useful.",
    ]

    meta = packet.get("meta", {})
    if isinstance(meta, dict):
        snapshot_summary = meta.get("snapshot_summary", {})
        if isinstance(snapshot_summary, dict) and snapshot_summary:
            system_prompt.append("Current game snapshot summary: " + json.dumps(snapshot_summary, ensure_ascii=False))

    messages = [{"role": "system", "content": "\n".join(system_prompt)}]
    history = packet.get("history", [])
    if isinstance(history, list):
        for item in history[-8:]:
            if not isinstance(item, dict):
                continue
            content = str(item.get("content", "")).strip()
            if content == "":
                continue
            raw_role = str(item.get("role", "user")).strip().lower()
            role = "assistant" if raw_role in ["assistant", "ai"] else "user"
            messages.append({"role": role, "content": content})

    message = str(packet.get("message", "")).strip()
    messages.append({"role": "user", "content": message})
    return messages


def read_http_json(url: str, timeout: float = 2.0) -> tuple[int, Dict[str, Any], str]:
    request = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw_text = response.read().decode("utf-8", errors="replace")
            return response.status, parse_json_object(raw_text), raw_text
    except urllib.error.HTTPError as exc:
        raw_text = exc.read().decode("utf-8", errors="replace")
        return exc.code, parse_json_object(raw_text), raw_text


def post_http_json(url: str, payload: Dict[str, Any], timeout: float = 240.0) -> Dict[str, Any]:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw_text = response.read().decode("utf-8", errors="replace")
            return parse_json_object(raw_text)
    except urllib.error.HTTPError as exc:
        raw_text = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"llama-server HTTP {exc.code}: {raw_text[:600]}") from exc


def parse_json_object(raw_text: str) -> Dict[str, Any]:
    try:
        parsed = json.loads(raw_text)
    except Exception:
        return {}
    return parsed if isinstance(parsed, dict) else {}


class LocalAIBackend:
    backend_id = "base"

    def __init__(self, model_id: str = "unset", options: Optional[Dict[str, Any]] = None) -> None:
        self.model_id = model_id
        self.options = options or {}

    def generate(self, packet: Dict[str, Any]) -> Dict[str, Any]:
        raise NotImplementedError


class EchoBackend(LocalAIBackend):
    backend_id = "echo"

    def generate(self, packet: Dict[str, Any]) -> Dict[str, Any]:
        message = str(packet.get("message", "")).strip()
        reply = f"[echo:{self.model_id}] {message}" if message else f"[echo:{self.model_id}]"
        return {
            "reply": reply,
            "backend": self.backend_id,
            "model": self.model_id,
        }


class LlamaCppBackend(LocalAIBackend):
    backend_id = "llama_cpp"

    def __init__(self, model_id: str = "unset", options: Optional[Dict[str, Any]] = None) -> None:
        super().__init__(model_id, options)
        try:
            from llama_cpp import Llama
        except Exception as exc:
            raise RuntimeError("llama-cpp-python is not installed for this Python.") from exc

        model_path = resolve_model_path(model_id)
        if not model_path.exists():
            raise FileNotFoundError(f"GGUF model not found: {model_path}")

        self.max_tokens = int(self.options.get("max_tokens", 256))
        self.temperature = float(self.options.get("temperature", 0.7))

        llama_kwargs: Dict[str, Any] = {
            "model_path": str(model_path),
            "n_ctx": int(self.options.get("n_ctx", 2048)),
            "verbose": bool(self.options.get("verbose", False)),
        }

        n_threads = int(self.options.get("n_threads", 0) or 0)
        if n_threads > 0:
            llama_kwargs["n_threads"] = n_threads

        n_gpu_layers = int(self.options.get("n_gpu_layers", 0) or 0)
        if n_gpu_layers > 0:
            llama_kwargs["n_gpu_layers"] = n_gpu_layers

        self.llm = Llama(**llama_kwargs)

    def generate(self, packet: Dict[str, Any]) -> Dict[str, Any]:
        prompt = build_plain_prompt(packet)
        output = self.llm(
            prompt,
            max_tokens=self.max_tokens,
            temperature=self.temperature,
            stop=["\nUSER:", "\nUser:", "\nAI:"],
        )
        choices = output.get("choices", []) if isinstance(output, dict) else []
        reply = ""
        if choices and isinstance(choices[0], dict):
            reply = str(choices[0].get("text", "")).strip()

        return {
            "reply": reply,
            "backend": self.backend_id,
            "model": self.model_id,
        }


class LlamaServerBackend(LocalAIBackend):
    backend_id = "llama_server"

    def __init__(self, model_id: str = "unset", options: Optional[Dict[str, Any]] = None) -> None:
        super().__init__(model_id, options)
        self.model_path = resolve_model_path(model_id)
        if not self.model_path.exists():
            raise FileNotFoundError(f"GGUF model not found: {self.model_path}")

        executable = resolve_llama_server_path(str(self.options.get("llama_server_path", "")))
        if executable is None:
            raise FileNotFoundError("llama-server executable was not found.")

        self.executable_path = executable
        self.host = str(self.options.get("llama_server_host", "127.0.0.1"))
        self.port = int(self.options.get("llama_server_port", DEFAULT_LLAMA_SERVER_PORT))
        self.base_url = f"http://{self.host}:{self.port}"
        self.health_url = self.base_url + "/health"
        self.chat_url = self.base_url + "/v1/chat/completions"
        self.max_tokens = int(self.options.get("max_tokens", 256))
        self.temperature = float(self.options.get("temperature", 0.7))
        self.startup_timeout_seconds = float(self.options.get("startup_timeout_seconds", 180.0))
        self.request_timeout_seconds = float(self.options.get("request_timeout_seconds", 240.0))
        self.process: Optional[subprocess.Popen[Any]] = None
        self.started_process = False
        self.chat_lock = threading.Lock()
        self.log_handle: Any = None
        self.log_path = resolve_project_path(str(self.options.get("llama_server_log_path", "local_ai/llama_server.log")))

        self.ensure_server_started()
        atexit.register(self.stop)

    def ensure_server_started(self) -> None:
        if self.server_is_alive():
            return
        if self.process is not None and self.process.poll() is None:
            return
        self.start_server_process()

    def start_server_process(self) -> None:
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.log_handle = self.log_path.open("a", encoding="utf-8")
        self.log_handle.write("\n--- starting llama-server ---\n")
        self.log_handle.flush()

        command = [
            str(self.executable_path),
            "--model",
            str(self.model_path),
            "--host",
            self.host,
            "--port",
            str(self.port),
            "--ctx-size",
            str(int(self.options.get("n_ctx", 2048))),
            "--n-gpu-layers",
            str(int(self.options.get("n_gpu_layers", 0))),
        ]

        n_threads = int(self.options.get("n_threads", 0) or 0)
        if n_threads > 0:
            command.extend(["--threads", str(n_threads)])

        creationflags = 0
        if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW"):
            creationflags = subprocess.CREATE_NO_WINDOW

        self.process = subprocess.Popen(
            command,
            cwd=str(self.executable_path.parent),
            stdout=self.log_handle,
            stderr=self.log_handle,
            creationflags=creationflags,
        )
        self.started_process = True

    def server_is_alive(self) -> bool:
        try:
            status_code, _data, _raw = read_http_json(self.health_url, timeout=2.0)
            return status_code in [200, 503]
        except Exception:
            return False

    def server_is_ready(self) -> bool:
        try:
            status_code, data, _raw = read_http_json(self.health_url, timeout=2.0)
        except Exception:
            return False
        return self.health_packet_is_ready(status_code, data)

    def health_packet_is_ready(self, status_code: int, data: Dict[str, Any]) -> bool:
        if status_code != 200:
            return False
        if not data:
            return True
        status = str(data.get("status", "")).lower()
        return status in ["ok", "ready"] or "slots_idle" in data

    def wait_until_ready(self, timeout_seconds: float) -> bool:
        deadline = time.time() + max(timeout_seconds, 1.0)
        while time.time() < deadline:
            if self.server_is_ready():
                return True
            if self.process is not None and self.process.poll() is not None:
                raise RuntimeError(
                    "llama-server exited before it became ready. Log tail: "
                    + self.get_log_tail()
                )
            time.sleep(0.5)
        return False

    def generate(self, packet: Dict[str, Any]) -> Dict[str, Any]:
        self.ensure_server_started()
        if not self.wait_until_ready(self.startup_timeout_seconds):
            raise RuntimeError("llama-server did not become ready before timeout. Log tail: " + self.get_log_tail())

        payload = {
            "model": "forever-space-local",
            "messages": build_chat_messages(packet),
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "stream": False,
        }

        with self.chat_lock:
            response = post_http_json(self.chat_url, payload, timeout=self.request_timeout_seconds)

        reply = self.extract_reply(response)
        return {
            "reply": reply,
            "backend": self.backend_id,
            "model": self.model_id,
        }

    def extract_reply(self, response: Dict[str, Any]) -> str:
        choices = response.get("choices", [])
        if not isinstance(choices, list) or not choices:
            return ""

        first = choices[0]
        if not isinstance(first, dict):
            return ""

        message = first.get("message", {})
        if isinstance(message, dict):
            content = message.get("content", "")
            if isinstance(content, str):
                return content.strip()

        return str(first.get("text", "")).strip()

    def diagnostics(self) -> Dict[str, Any]:
        status_code = 0
        data: Dict[str, Any] = {}
        try:
            status_code, data, _raw = read_http_json(self.health_url, timeout=0.25)
        except Exception:
            pass

        process_id = self.process.pid if self.process is not None else -1
        process_running = self.process is not None and self.process.poll() is None
        return {
            "mode": "llama_server_inference",
            "inference_ready": self.health_packet_is_ready(status_code, data),
            "llama_server_url": self.base_url,
            "llama_server_health_code": status_code,
            "llama_server_pid": process_id,
            "llama_server_process_running": process_running,
            "llama_server_started_process": self.started_process,
            "llama_server_executable": str(self.executable_path),
            "llama_server_log_path": str(self.log_path),
        }

    def get_log_tail(self, max_chars: int = 1200) -> str:
        try:
            if self.log_handle is not None:
                self.log_handle.flush()
            if not self.log_path.exists():
                return ""
            raw_text = self.log_path.read_text(encoding="utf-8", errors="replace")
            return raw_text[-max_chars:]
        except Exception:
            return ""

    def stop(self) -> None:
        if self.started_process and self.process is not None and self.process.poll() is None:
            try:
                self.process.terminate()
            except Exception:
                pass
        if self.log_handle is not None:
            try:
                self.log_handle.close()
            except Exception:
                pass


BACKENDS: Dict[str, Type[LocalAIBackend]] = {
    EchoBackend.backend_id: EchoBackend,
    LlamaCppBackend.backend_id: LlamaCppBackend,
    LlamaServerBackend.backend_id: LlamaServerBackend,
}


class LocalAIState:
    def __init__(self, backend_id: str, model_id: str, options: Optional[Dict[str, Any]] = None) -> None:
        if backend_id not in BACKENDS:
            raise ValueError(f"Unknown backend '{backend_id}'. Available: {', '.join(sorted(BACKENDS.keys()))}")

        self.backend_id = backend_id
        self.model_id = model_id
        self.started_at = time.time()
        self.backend = BACKENDS[backend_id](model_id, options or {})

    def health(self) -> Dict[str, Any]:
        diagnostics = self.diagnostics()
        return {
            "ok": True,
            "service": "forever_space_local_ai",
            "backend": self.backend_id,
            "model": self.model_id,
            "pid": os.getpid(),
            "mode": diagnostics.get("mode"),
            "inference_ready": diagnostics.get("inference_ready"),
            "model_exists": diagnostics.get("model_exists"),
            "uptime_seconds": round(time.time() - self.started_at, 3),
            "available_backends": sorted(BACKENDS.keys()),
        }

    def chat(self, packet: Dict[str, Any]) -> Dict[str, Any]:
        response = self.backend.generate(packet)
        diagnostics = self.diagnostics()
        result = {
            "ok": True,
            "request_id": str(packet.get("request_id", "")) or uuid.uuid4().hex,
            "conversation_id": str(packet.get("conversation_id", "")),
            "reply": str(response.get("reply", "")),
            "backend": str(response.get("backend", self.backend_id)),
            "model": str(response.get("model", self.model_id)),
            "mode": diagnostics.get("mode"),
            "inference_ready": diagnostics.get("inference_ready"),
            "created_at_unix": time.time(),
        }
        if self.backend_id == EchoBackend.backend_id:
            result["debug_note"] = "Echo backend is a wire test only. The GGUF model was not used for this reply."
        return result

    def diagnostics(self) -> Dict[str, Any]:
        return build_runtime_diagnostics(self)


def build_backend_preflight_diagnostics(backend_id: str, model_id: str) -> Dict[str, Any]:
    model_path = resolve_model_path(model_id)
    model_exists = model_path.exists()
    llama_cpp_installed = importlib.util.find_spec("llama_cpp") is not None
    llama_executables = find_llama_executables()
    llama_server_executables = find_llama_server_executables()

    if backend_id == EchoBackend.backend_id:
        mode = "echo_wire_test"
        inference_ready = False
        issue = "Echo backend is active, so replies are generated by code and the model file is not loaded."
    elif backend_id == LlamaCppBackend.backend_id:
        mode = "local_model_inference"
        inference_ready = model_exists and llama_cpp_installed
        issue = "" if inference_ready else "llama_cpp backend selected but model path or llama-cpp-python is missing."
    elif backend_id == LlamaServerBackend.backend_id:
        mode = "llama_server_inference"
        inference_ready = model_exists and bool(llama_server_executables)
        issue = "" if inference_ready else "llama_server backend selected but model path or llama-server executable is missing."
    else:
        mode = "custom_backend"
        inference_ready = True
        issue = ""

    return {
        "ok": True,
        "service": "forever_space_local_ai",
        "backend": backend_id,
        "model": model_id,
        "model_path": str(model_path),
        "model_exists": model_exists,
        "model_size_bytes": model_path.stat().st_size if model_exists else 0,
        "mode": mode,
        "inference_ready": inference_ready,
        "diagnostic_issue": issue,
        "llama_cpp_python_installed": llama_cpp_installed,
        "llama_executables_found": llama_executables,
        "llama_server_executables_found": llama_server_executables,
        "available_backends": sorted(BACKENDS.keys()),
    }


def build_runtime_diagnostics(state: LocalAIState) -> Dict[str, Any]:
    diagnostics = build_backend_preflight_diagnostics(state.backend_id, state.model_id)
    backend_diagnostics = getattr(state.backend, "diagnostics", None)
    if callable(backend_diagnostics):
        diagnostics.update(backend_diagnostics())
    diagnostics["backend_loaded"] = True
    return diagnostics


def load_json_config(path: str) -> Dict[str, Any]:
    clean_path = str(path or "").strip()
    if clean_path == "":
        return {}

    config_path = Path(clean_path)
    if not config_path.exists():
        return {}

    with config_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    if not isinstance(data, dict):
        raise ValueError(f"Config root must be an object: {config_path}")

    return data


def make_handler(state: LocalAIState):
    class LocalAIRequestHandler(BaseHTTPRequestHandler):
        server_version = "ForeverSpaceLocalAI/0.1"

        def log_message(self, fmt: str, *args: Any) -> None:
            print("%s - %s" % (self.address_string(), fmt % args))

        def _send_json(self, status_code: int, payload: Dict[str, Any]) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status_code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Accept")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.end_headers()
            self.wfile.write(body)

        def _read_json_body(self) -> Dict[str, Any]:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0:
                return {}
            if content_length > MAX_BODY_BYTES:
                raise ValueError("Request body is too large.")

            raw = self.rfile.read(content_length)
            data = json.loads(raw.decode("utf-8"))
            if not isinstance(data, dict):
                raise ValueError("Request JSON root must be an object.")
            return data

        def do_OPTIONS(self) -> None:
            self._send_json(200, {"ok": True})

        def do_GET(self) -> None:
            path = urlparse(self.path).path
            if path == "/health":
                self._send_json(200, state.health())
                return
            if path == "/diagnostics":
                self._send_json(200, state.diagnostics())
                return
            if path == "/models":
                self._send_json(200, {
                    "ok": True,
                    "active_backend": state.backend_id,
                    "active_model": state.model_id,
                    "available_backends": sorted(BACKENDS.keys()),
                })
                return

            self._send_json(404, {"ok": False, "error": "Unknown endpoint."})

        def do_POST(self) -> None:
            path = urlparse(self.path).path
            if path != "/chat":
                self._send_json(404, {"ok": False, "error": "Unknown endpoint."})
                return

            try:
                packet = self._read_json_body()
                self._send_json(200, state.chat(packet))
            except Exception as exc:
                self._send_json(400, {"ok": False, "error": str(exc)})

    return LocalAIRequestHandler


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Forever Space local AI localhost server.")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=parse_intish, default=DEFAULT_PORT)
    parser.add_argument("--backend", default="echo", choices=sorted(BACKENDS.keys()))
    parser.add_argument("--model", default="echo")
    parser.add_argument("--config", default="")
    parser.add_argument("--allow-lan", action="store_true", help="Allow binding to non-loopback hosts.")
    parser.add_argument("--n-ctx", type=parse_intish, default=2048)
    parser.add_argument("--n-threads", type=parse_intish, default=0)
    parser.add_argument("--n-gpu-layers", type=parse_intish, default=0)
    parser.add_argument("--max-tokens", type=parse_intish, default=256)
    parser.add_argument("--temperature", type=float, default=0.7)
    parser.add_argument("--llama-server-path", default="")
    parser.add_argument("--llama-server-host", default="127.0.0.1")
    parser.add_argument("--llama-server-port", type=parse_intish, default=DEFAULT_LLAMA_SERVER_PORT)
    parser.add_argument("--startup-timeout-seconds", type=float, default=180.0)
    parser.add_argument("--request-timeout-seconds", type=float, default=240.0)
    parser.add_argument("--llama-server-log-path", default="local_ai/llama_server.log")
    parser.add_argument("--list-backends", action="store_true")
    parser.add_argument("--diagnostics", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    parser.set_defaults(backend_options={})
    return parser


def merge_config(args: argparse.Namespace) -> argparse.Namespace:
    config = load_json_config(args.config)
    server_config = config.get("server", {})
    if not isinstance(server_config, dict):
        server_config = {}

    for key in ["host", "port", "backend", "model"]:
        for source in [config, server_config]:
            if key in source and source[key] not in [None, ""]:
                setattr(args, key, source[key])

    if "server_host" in config and config["server_host"] not in [None, ""]:
        args.host = config["server_host"]
    if "server_port" in config and config["server_port"] not in [None, ""]:
        args.port = config["server_port"]
    if "model_id" in config and "model" not in config and "model" not in server_config:
        args.model = config["model_id"]

    backend_options: Dict[str, Any] = {}
    for source in [config.get("backend_options", {}), server_config.get("backend_options", {})]:
        if isinstance(source, dict):
            backend_options.update(source)
    args.backend_options = backend_options

    option_arg_names = [
        "n_ctx",
        "n_threads",
        "n_gpu_layers",
        "max_tokens",
        "temperature",
        "llama_server_path",
        "llama_server_host",
        "llama_server_port",
        "startup_timeout_seconds",
        "request_timeout_seconds",
        "llama_server_log_path",
    ]
    for key in option_arg_names:
        if key in backend_options and backend_options[key] not in [None, ""]:
            setattr(args, key, backend_options[key])
    return args


def assert_local_bind(host: str, allow_lan: bool) -> None:
    if allow_lan:
        return
    if host not in ["127.0.0.1", "localhost", "::1"]:
        raise ValueError("Refusing non-local bind without --allow-lan.")


def run_self_test(args: argparse.Namespace) -> int:
    try:
        state = LocalAIState(str(args.backend), str(args.model), get_backend_options(args))
    except Exception as exc:
        print(json.dumps({
            "ok": False,
            "error": str(exc),
            "backend": str(args.backend),
            "model": str(args.model),
            "diagnostics": build_backend_preflight_diagnostics(str(args.backend), str(args.model)),
        }, indent=2))
        return 1

    response = state.chat({
        "message": "self test",
        "conversation_id": "self_test",
        "request_id": "self_test_001",
    })
    print(json.dumps(response, indent=2))
    return 0 if response.get("ok") and response.get("reply") else 1


def get_backend_options(args: argparse.Namespace) -> Dict[str, Any]:
    options = dict(getattr(args, "backend_options", {}) or {})
    options.update({
        "n_ctx": parse_intish(args.n_ctx),
        "n_threads": parse_intish(args.n_threads),
        "n_gpu_layers": parse_intish(args.n_gpu_layers),
        "max_tokens": parse_intish(args.max_tokens),
        "temperature": float(args.temperature),
        "llama_server_path": str(args.llama_server_path),
        "llama_server_host": str(args.llama_server_host),
        "llama_server_port": parse_intish(args.llama_server_port),
        "startup_timeout_seconds": float(args.startup_timeout_seconds),
        "request_timeout_seconds": float(args.request_timeout_seconds),
        "llama_server_log_path": str(args.llama_server_log_path),
    })
    return options


def main() -> int:
    parser = build_arg_parser()
    args = merge_config(parser.parse_args())

    if args.list_backends:
        print("\n".join(sorted(BACKENDS.keys())))
        return 0

    assert_local_bind(str(args.host), bool(args.allow_lan))

    if args.self_test:
        return run_self_test(args)

    if args.diagnostics:
        print(json.dumps(build_backend_preflight_diagnostics(str(args.backend), str(args.model)), indent=2))
        return 0

    try:
        state = LocalAIState(str(args.backend), str(args.model), get_backend_options(args))
    except Exception as exc:
        print(json.dumps({
            "ok": False,
            "error": str(exc),
            "backend": str(args.backend),
            "model": str(args.model),
            "diagnostics": build_backend_preflight_diagnostics(str(args.backend), str(args.model)),
        }, indent=2))
        return 1

    server = ThreadingHTTPServer((str(args.host), int(args.port)), make_handler(state))
    print(f"Forever Space local AI server listening on http://{args.host}:{args.port}")
    print(f"Backend={state.backend_id} model={state.model_id}")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
