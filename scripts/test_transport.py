#!/usr/bin/env python3
"""Exercise real curl + Lean against a loopback Responses server; no models or keys needed."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
REQUESTS = []


def completion(text):
    return {
        "status": "completed",
        "output": [
            {"type": "reasoning", "summary": []},
            {"type": "message", "role": "assistant", "status": "completed",
             "content": [{"type": "output_text", "text": text}]},
        ],
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, status, body):
        data = json.dumps(body).encode() if not isinstance(body, bytes) else body
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except BrokenPipeError:
            pass  # The timeout test intentionally disconnects.

    def do_GET(self):
        assert self.path == "/v1/models", self.path
        self.reply(200, {"data": [{"id": "stub-model"}]})

    def do_POST(self):
        assert self.path == "/v1/responses", self.path
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        REQUESTS.append((request, self.headers.get("Authorization")))
        fields = {"model", "instructions", "input", "max_output_tokens", "store", "stream"}
        if "reasoning" in request:
            fields.add("reasoning")
            assert request["reasoning"] == {"effort": "none"}
        assert set(request) == fields
        assert request["store"] is False and request["stream"] is False
        model = request["model"]
        if model == "stub-import":
            assert "theorem ContextExample.ListTools.length_append_one" in request["input"]
            assert "TARGET_AFTER_HOLE" not in request["input"]
            return self.reply(200, completion("```lean\nexact ContextExample.ListTools.length_append_one xs x\n```"))
        if model == "stub-context":
            return self.reply(200, completion("```lean\nsimpa only [ContextBench.pushTwice_eq, ContextExample.ListTools.length_append_one] using hlen\n```"))
        if model == "stub-auth-error":
            return self.reply(401, {"error": {"message": "test authentication error"}})
        if model == "stub-truncated":
            body = completion("```lean\nrfl\n```")
            body.update(status="incomplete", incomplete_details={"reason": "max_output_tokens"})
            return self.reply(200, body)
        if model == "stub-bad-json":
            return self.reply(200, b"<html>proxy error</html>")
        if model == "stub-timeout":
            time.sleep(2)
        if "Complete all current goals" in request["instructions"]:
            if "Lean feedback:" not in request["input"]:
                return self.reply(200, completion("```lean\nconstructor\n```"))
            assert "Remaining goals:" in request["input"]
            text = "constructor\n· trivial\n· trivial"
        elif "replacement must begin with: exact " in request["input"]:
            text = "exact True.intro"
        else:
            text = "rfl"
        self.reply(200, completion(f"```lean\n{text}\n```"))


def run(command, env, expected=0, contains=None, cwd=ROOT):
    result = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True, timeout=30)
    output = result.stdout + result.stderr
    assert (result.returncode == 0) == (expected == 0), output
    if contains:
        assert contains in output, output
    return output


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory(prefix="llmlean-test-") as folder:
            folder = Path(folder)
            config = folder / "config.toml"
            config.write_text(f'base_url = "http://127.0.0.1:{server.server_port}/v1"\n')
            # Never forward real credentials or the developer's LLMLean configuration.
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith("LLMLEAN_") and k not in {"OPENAI_API_KEY", "OPENROUTER_API_KEY"}}
            env.update(LLMLEAN_CONFIG=str(config), LLMLEAN_PROVIDER="local", LLMLEAN_MODEL="stub-model")
            source = folder / "Example.lean"
            source.write_text('''module
import LLMlean
example (n : Nat) : n = n := by
  llmstep
  rfl
example : True := by
  llmstep "exact "
  trivial
example : True ∧ True := by
  llmqed
  exact ⟨True.intro, True.intro⟩
''')
            # With no provider/model override, OpenAI's default model must reach the wire.
            default_env = {k: v for k, v in env.items()
                           if k not in {"LLMLEAN_PROVIDER", "LLMLEAN_MODEL"}}
            default_env["OPENAI_API_KEY"] = "test-default-key"
            start = len(REQUESTS)
            run(["lake", "env", "lean", str(source)], default_env, contains="Try this:")
            calls = REQUESTS[start:]
            assert len(calls) == 4, calls
            assert all(body["model"] == "gpt-6-luna" and auth == "Bearer test-default-key"
                       for body, auth in calls)

            # All three presets must take the identical transport and proof-checking path.
            for provider, key_name in [("local", "LLMLEAN_API_KEY"),
                                       ("openai", "OPENAI_API_KEY"),
                                       ("openrouter", "OPENROUTER_API_KEY")]:
                test_env = dict(env, LLMLEAN_PROVIDER=provider)
                test_env[key_name] = 'test-key-"with\\quotes'
                start = len(REQUESTS)
                run(["lake", "env", "lean", str(source)], test_env, contains="Try this:")
                calls = REQUESTS[start:]
                assert len(calls) == 4, calls
                assert all(auth == 'Bearer test-key-"with\\quotes' for _, auth in calls)
                assert all("reasoning" not in body for body, _ in calls)

            # An explicit reasoning override must reach every request, including repairs.
            start = len(REQUESTS)
            run(["lake", "env", "lean", str(source)],
                dict(env, LLMLEAN_REASONING_EFFORT="none"), contains="Try this:")
            calls = REQUESTS[start:]
            assert len(calls) == 4, calls
            assert all(body.get("reasoning") == {"effort": "none"} for body, _ in calls)

            # Imported project statements must reach the actual transport, with no future source.
            source.write_text('''module
import LLMlean
import Tests.ContextBridge
example {α : Type} (xs : List α) (x : α) : (xs ++ [x]).length = xs.length + 1 := by
  llmqed
  -- TARGET_AFTER_HOLE
  exact ContextExample.ListTools.length_append_one xs x
''')
            run(["lake", "env", "lean", str(source)], dict(env, LLMLEAN_MODEL="stub-import"),
                contains="Try this:")
            # Exercise the benchmark's opt-in model path using the same isolated loopback server.
            start = len(REQUESTS)
            output = run(["python3", "scripts/benchmark_context.py", "--case", "imports_transitive", "--prove"],
                dict(env, LLMLEAN_MODEL="stub-context"), contains='"solved": true')
            assert len(REQUESTS) == start + 4
            rows = [json.loads(line) for line in output.splitlines() if line.startswith('{')]
            assert {row['mode'] for row in rows} == {'full', 'window', 'all_files', 'structured'}
            assert len(rows) == 4 and all(row['solved'] for row in rows)
            assert all(row['total_input_chars'] == row['input_chars'] + row['instruction_chars'] for row in rows)

            doctor = [str(ROOT / ".lake/build/bin/llmlean"), "doctor"]
            run(doctor, env, contains="model available")
            run(doctor + ["--offline"], dict(env, LLMLEAN_REASONING_EFFORT="none"),
                contains="Reasoning effort: none")
            run(doctor, dict(env, LLMLEAN_MODEL="missing"), expected=1, contains="ollama pull missing")
            run(doctor, dict(env, LLMLEAN_PROVIDER="openai"), expected=1, contains="OPENAI_API_KEY")
            missing_default_key = {k: v for k, v in default_env.items() if k != "OPENAI_API_KEY"}
            run(doctor, missing_default_key, expected=1, contains="OPENAI_API_KEY")
            run(doctor + ["--offline"], missing_default_key,
                contains="Provider: openai\nModel: gpt-6-luna")
            run(doctor + ["--offline"], dict(env, LLMLEAN_CONFIG=str(folder / "missing.toml")),
                expected=1, contains="does not exist")

            # A project config isolates the demo from old global settings; an explicit
            # config path must still win. Exercise the real file loader, not a mock.
            config_env = {k: v for k, v in env.items() if not k.startswith("LLMLEAN_")}
            home = folder / "home"
            xdg = home / ".config"
            global_config = xdg / "llmlean" / "config.toml"
            global_config.parent.mkdir(parents=True)
            global_config.write_text('api = "legacy"\n')
            config_env.update(HOME=str(home), XDG_CONFIG_HOME=str(xdg), APPDATA=str(xdg))
            run(doctor + ["--offline"], config_env, cwd=folder,
                expected=1, contains="Unsupported configuration key 'api'")
            (folder / "llmlean.toml").write_text('model = "project-model"\n')
            run(doctor + ["--offline"], config_env, cwd=folder, contains="Model: project-model")
            explicit = folder / "explicit.toml"
            explicit.write_text('model = "explicit-model"\n')
            run(doctor + ["--offline"], dict(config_env, LLMLEAN_CONFIG=str(explicit)),
                cwd=folder, contains="Model: explicit-model")
            run(doctor + ["--offline"],
                dict(config_env, LLMLEAN_CONFIG=str(folder / "missing.toml")),
                cwd=folder, expected=1, contains="does not exist")

            source.write_text("module\nimport LLMlean\nexample (n : Nat) : n = n := by\n  llmstep\n  rfl\n")
            for model, message in [("stub-auth-error", "HTTP 401"), ("stub-truncated", "incomplete"),
                                   ("stub-bad-json", "invalid JSON"), ("stub-timeout", "timed out")]:
                start = len(REQUESTS)
                run(["lake", "env", "lean", str(source)],
                    dict(env, LLMLEAN_MODEL=model, LLMLEAN_TIMEOUT_SECONDS="1"),
                    expected=1, contains=message)
                assert len(REQUESTS) == start + 1, "Transport failure must not trigger extra model calls"
    finally:
        server.shutdown()
        server.server_close()
    print("Loopback transport tests passed for local, OpenAI, and OpenRouter presets.")


if __name__ == "__main__":
    main()
