#!/usr/bin/env python3
"""Check the optimizer CLI and a real Lean LSP action against a loopback Responses server."""
import contextlib
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import queue
import signal
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'Tests/OptimizeExample.lean'
PROOF = 'by exact ⟨h.right, h.left⟩'


class Session:
    def __init__(self, env, cwd=ROOT):
        self.proc = subprocess.Popen(['lake', 'serve'], cwd=cwd, env=env, stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, start_new_session=True)
        self.inbox = queue.Queue()
        self.notifications = []
        self.previews = []
        self.reader = threading.Thread(target=self.read, daemon=True)
        self.reader.start()

    def read(self):
        while line := self.proc.stdout.readline():
            if not line.lower().startswith(b'content-length:'):
                continue
            length = int(line.split(b':', 1)[1])
            while self.proc.stdout.readline().strip():
                pass
            self.inbox.put(json.loads(self.proc.stdout.read(length)))

    def write(self, msg):
        data = json.dumps(msg).encode()
        self.proc.stdin.write(f'Content-Length: {len(data)}\r\n\r\n'.encode() + data)
        self.proc.stdin.flush()

    def send(self, method, params, request_id=None):
        msg = dict(jsonrpc='2.0', method=method, params=params)
        if request_id is not None:
            msg['id'] = request_id
        self.write(msg)
        if request_id is not None:
            while True:
                reply = self.inbox.get(timeout=100)
                if reply.get('method') == 'workspace/applyEdit':
                    self.previews.append(reply)
                    continue
                if 'method' in reply and 'id' not in reply:
                    self.notifications.append(reply)
                    continue
                if 'method' in reply and 'id' in reply:
                    self.write(dict(jsonrpc='2.0', id=reply['id'], result=None))
                    continue
                if reply.get('id') == request_id:
                    assert 'error' not in reply, reply.get('error')
                    return reply['result']

    def close(self):
        os.killpg(self.proc.pid, signal.SIGTERM)
        self.proc.wait(timeout=10)
        self.reader.join(timeout=5)
        self.proc.stdin.close()
        self.proc.stdout.close()


def check_demo_infoview(env, calls):
    demo = ROOT / 'LLMleanDemo'
    path = demo / 'Demo.lean'
    uri = path.as_uri()
    source = path.read_text()
    theorem = next(i for i, line in enumerate(source.splitlines()) if 'theorem Demo.swap ' in line)
    pos = dict(line=theorem + 1, character=4)
    with contextlib.closing(Session(env, cwd=demo)) as lsp:
        lsp.send('initialize', dict(processId=os.getpid(), rootUri=demo.as_uri(), capabilities={
            'window': {'workDoneProgress': True},
            'textDocument': {'codeAction': {'honorsChangeAnnotations': True}},
            'workspace': {'applyEdit': True, 'workspaceEdit': {'documentChanges': True, 'changeAnnotationSupport': {}}}
        }), 1)
        lsp.send('initialized', {})
        lsp.send('textDocument/didOpen', dict(textDocument=dict(uri=uri, languageId='lean4', version=1, text=source)))
        params = dict(textDocument=dict(uri=uri), range=dict(start=pos, end=pos), context=dict(diagnostics=[]))
        actions = lsp.send('textDocument/codeAction', params, 2)
        action = next(a for a in actions if a['title'] == 'LLMLean: Optimize proof')
        session = lsp.send('$/lean/rpc/connect', {'uri': uri}, 3)['sessionId']

        def rpc(method, args, request_id, position=pos):
            return lsp.send('$/lean/rpc/call', dict(textDocument=dict(uri=uri), position=position,
                sessionId=session, method=method, params=args), request_id)

        panel = 'LLMlean.Optimize.Panel.'
        assert rpc(panel + 'status', pos, 4) is None
        widgets = rpc('Lean.Widget.getWidgets', pos, 5)['widgets']
        assert any(w['id'].endswith('.optimizerPanel') for w in widgets)
        prior = len(calls)
        assert 'edit' not in lsp.send('codeAction/resolve', action, 6)
        assert len(calls) == prior + 1
        values = [n['params']['value'] for n in lsp.notifications if n['method'] == '$/progress']
        assert [v['kind'] for v in values] == ['begin', 'report', 'report', 'report', 'end']
        assert values[0]['title'] == 'Optimizing Demo.swap'
        assert [v['message'] for v in values[1:-1]] == [
            'Collecting goals and referenced lemmas…', 'Waiting for local LLM…', 'Checking proof in Lean…']
        state = rpc(panel + 'status', pos, 7)
        assert state['message'] == 'Verified by Lean' and state['metrics']['tokens'][0] > state['metrics']['tokens'][1] and not state['canReview']
        other = dict(line=0, character=0)
        assert rpc(panel + 'status', other, 8, other) is None
        preview, = lsp.previews
        edit = preview['params']['edit']
        assert edit['documentChanges'][0]['textDocument'] == {'uri': uri, 'version': 1}
        assert edit['changeAnnotations']['optimize']['needsConfirmation']
        lsp.write(dict(jsonrpc='2.0', id=preview['id'], error={'code': -32603, 'message': 'Internal client details'}))
        for index in range(30):
            failed_preview = rpc(panel + 'status', pos, 10 + index)
            if failed_preview['canReview']:
                assert failed_preview['message'] == 'Could not open the proof preview.'
                break
        else:
            raise AssertionError('Failed preview could not be reviewed')
        args = {'id': state['id'], 'pos': pos}
        rpc(panel + 'review', args, 40)
        assert len(lsp.previews) == 2 and lsp.previews[1]['params']['edit'] == edit
        lsp.write(dict(jsonrpc='2.0', id=lsp.previews[1]['id'], result={'applied': False}))
        lsp.send('textDocument/didChange', dict(textDocument=dict(uri=uri, version=2),
                                               contentChanges=[dict(text=source + '\n')]))
        assert rpc(panel + 'status', pos, 41) is None
        rpc(panel + 'review', args, 42)
        assert len(lsp.previews) == 2 and len(calls) == prior + 1


def comparable_messages(messages):
    # Lean allocates fresh metavariable names on the server's async elaboration branches.
    # Preserve goal identity across observations when comparing to synchronous CLI extraction.
    payload = json.loads(messages[1]['content'])
    ids = {}
    for entry in payload['tactic_state_trace']['entries']:
        for side in ('goals_before', 'goals_after'):
            for goal in entry[side]:
                goal['id'] = ids.setdefault(goal['id'], len(ids))
    return messages[0], messages[1]['role'], payload


def check_editor_scope(env, calls, response):
    source = """import LLMlean
namespace ScopeTest
section
variable {P Q : Prop}
local macro "closePair" : tactic => `(tactic| grind)
local macro "closeNamed " _label:ident : tactic => `(tactic| grind)
theorem _root_.And.swapViaDot (h : P ∧ Q) : Q ∧ P := by grind
axiom unproved (h : P ∧ Q) : Q ∧ P

theorem target (h : P ∧ Q) : Q ∧ P := by
  have hp : P := h.left
  have hq : Q := h.right
  exact ⟨hq, hp⟩

theorem later (h : P ∧ Q) : Q ∧ P := by grind
example : False := by trivial
end
end ScopeTest
"""
    pos = dict(line=next(i for i, line in enumerate(source.splitlines()) if 'have hq' in line), character=6)
    uri = FIXTURE.as_uri()
    document = dict(uri=uri)
    params = dict(textDocument=document, range=dict(start=pos, end=pos), context=dict(diagnostics=[]))
    with contextlib.closing(Session(env)) as lsp:
        lsp.send('initialize', dict(processId=os.getpid(), rootUri=ROOT.as_uri(), capabilities={
            'window': {'workDoneProgress': True},
            'workspace': {'workspaceEdit': {'documentChanges': True}}
        }), 1)
        lsp.send('initialized', {})
        lsp.send('textDocument/didOpen', dict(textDocument=dict(uri=uri, languageId='lean4', version=1, text=source)))
        session = lsp.send('$/lean/rpc/connect', {'uri': uri}, 3)['sessionId']
        cases = [
            (None, False),  # The model endpoint returns HTTP 503.
            ('by exact ⟨hq, hp⟩', False),
            ('by exact later h', False),
            ('by exact unproved h', False),
            ('by sorry', False),
            ('by grind\ntheorem extra : True := by trivial', False),
            (source.split('theorem target')[1].split(':= ', 1)[1].split('\n\ntheorem later')[0], False),
            ('by closeNamed label', False),
            ('by exact .swapViaDot h', True),
            ('by exact .intro h.right h.left', True),
            ('by closePair', True)
        ]
        for i, (proof, improved) in enumerate(cases):
            response[0] = proof
            actions = lsp.send('textDocument/codeAction', params, 10 + 2*i)
            action = next(a for a in actions if a['title'] == 'LLMLean: Optimize proof')
            count = len(calls)
            resolved = lsp.send('codeAction/resolve', action, 11 + 2*i)
            assert len(calls) == count + 1, lsp.notifications[-3:]
            assert ('edit' in resolved) == improved, (proof, lsp.notifications[-3:])
            if improved:
                assert resolved['edit']['documentChanges'][0]['edits'][0]['newText'] == proof
            if improved and ('.swapViaDot' in proof or '.intro' in proof):
                label = resolved['edit']['changeAnnotations']['optimize']['label']
                lemma_count = 1 if '.swapViaDot' in proof else 2
                assert label.endswith(f'explicit lemmas 2 → {lemma_count}'), label
            if not improved:
                message = 'Failed to find an improved proof.'
                assert lsp.notifications[-1]['params']['value']['message'] == message
                status = lsp.send('$/lean/rpc/call', dict(textDocument=document, position=pos,
                    sessionId=session, method='LLMlean.Optimize.Panel.status', params=pos), 100 + i)
                assert status['finished'] and status['message'] == message
                assert status['metrics'] is None and not status['canReview']
        payload = json.loads(calls[-1]['input'][1]['content'])
        assert payload['original_environment']['namespace'] == 'ScopeTest'
        assert payload['original_environment']['section_variables']
        entries = payload['tactic_state_trace']['entries']
        assert entries[0]['source'].startswith('have hp') and entries[-1]['goals_after'] == []
        assert 'hp : P' not in entries[0]['goals_before'][0]['pretty']


def test():
    calls = []
    tokenizer_calls = []
    response = [PROOF]
    lock = threading.Lock()
    active = peak = 0

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            nonlocal active, peak
            request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            if self.path == '/tokenize':
                tokenizer_calls.append(request)
                payload = json.loads(request['messages'][1]['content'])
                added = len(payload.get('additional_available_lemmas', []))
                body = json.dumps(dict(count=100 + 50 * added, max_model_len=2198)).encode()
                self.send_response(200)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            assert self.path == '/v1/responses'
            with lock:
                calls.append(request)
                proof = response.pop(0) if len(response) > 1 else response[0]
                active += 1
                peak = max(peak, active)
            try:
                if 'temperature' in request:
                    time.sleep(0.05)
                if proof is None:
                    self.send_error(503)
                    return
                body = json.dumps(dict(status='completed', output=[dict(type='message', role='assistant',
                    content=[dict(type='output_text', text=proof)])])).encode()
                self.send_response(200)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            finally:
                with lock:
                    active -= 1

    with ThreadingHTTPServer(('127.0.0.1', 0), Handler) as server, tempfile.TemporaryDirectory() as tmp:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        cfg = Path(tmp) / 'llmlean.toml'
        cfg.write_text('provider="local"\n')
        env = dict(os.environ, LLMLEAN_CONFIG=str(cfg), LLMLEAN_BASE_URL=f'http://127.0.0.1:{server.server_port}/v1',
                   LLMLEAN_MODEL='fixture', LLMLEAN_OPTIMIZE_CANDIDATES='1', LLMLEAN_OPTIMIZE_RETRIEVAL_TOKENS='0', OPENAI_API_KEY='loopback-fixture-key', LLMLEAN_API_KEY='')
        # Run the installed application with Python and uv unavailable to child processes.
        blocked = Path(tmp) / 'bin'
        blocked.mkdir()
        for tool in ('uv', 'python', 'python3'):
            shim = blocked / tool
            shim.write_text('#!/bin/sh\nexit 127\n')
            shim.chmod(0o755)
        env['PATH'] = str(blocked) + os.pathsep + env['PATH']
        cli = [str(ROOT / '.lake/build/bin/llmlean'), 'optimize']
        def run(path, flags=(), provider='local', candidates=1, retrieval=0):
            return subprocess.check_output(cli + [str(path), '--decl', 'OptimizeExample.swap', *flags],
                                          cwd=ROOT, env=dict(env, LLMLEAN_PROVIDER=provider,
                                                             LLMLEAN_OPTIMIZE_CANDIDATES=str(candidates),
                                                             LLMLEAN_OPTIMIZE_RETRIEVAL_TOKENS=str(retrieval)), text=True)
        expected = json.loads(run(FIXTURE, ['--dump-prompt']))['messages']
        system, _, payload = comparable_messages(expected)
        assert system == {'role': 'system', 'content': (ROOT / 'LLMlean/Optimize/SystemPrompt.txt').read_text().rstrip()}
        # The context payload matches the training formatter after normalizing fresh goal IDs.
        content = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
        assert hashlib.sha256(content.encode()).hexdigest() == (
            'a642d1d8f5b375ae6ba5ef25a30023a20c912d4a0dd538b115827dfc26c27708')
        original = FIXTURE.read_bytes()
        for provider in ['openai', 'local']:
            start = len(calls)
            assert 'Proof tokens' in run(FIXTURE, provider=provider, candidates=32 if provider == 'openai' else 1,
                                         retrieval=1024 if provider == 'openai' else 0)
            assert len(calls) == start + 1 and 'temperature' not in calls[-1]
            assert calls[-1]['input'] == expected and calls[-1]['max_output_tokens'] == 2048
        assert calls[-1]['reasoning'] == {'effort': 'none'}
        assert FIXTURE.read_bytes() == original and not tokenizer_calls
        with tempfile.NamedTemporaryFile(prefix='Retrieval', suffix='.lean', dir=FIXTURE.parent) as copy:
            copy.write(original.replace(b'theorem swap', b'theorem earlier : True := by trivial\n\ntheorem swap')
                       .replace(b'end OptimizeExample', b'theorem later : True := by trivial\nend OptimizeExample'))
            copy.flush()
            plain = json.loads(run(copy.name, ['--dump-prompt']))['messages']
            start = len(calls)
            summary = run(copy.name, candidates=32, retrieval=1024)
            inputs = [r['input'] for r in calls[start:]]
            assert len(inputs) == 32 and all(m == inputs[0] for m in inputs)
            enhanced = inputs[0]
            assert enhanced[0] == plain[0]
            lemmas = json.loads(enhanced[1]['content'])['additional_available_lemmas']
            assert len(lemmas) == 1 and lemmas[0].split()[1] in {'OptimizeExample.earlier', 'OptimizeExample.keep'}
            assert enhanced[1]['content'].startswith(plain[1]['content'][:-1] + ',"additional_available_lemmas":')
            assert '+50 prompt tokens' in summary
            assert '0 retrieved signatures' in run(copy.name, retrieval=49)
            assert calls[-1]['input'] == plain
        response[0] = 'by sorry'
        assert 'No verified improvement' in run(FIXTURE)
        response[0] = PROOF
        # Use a private copy of the fixture in a registered Lake source directory.
        with tempfile.NamedTemporaryFile(prefix='Optimizer', suffix='.lean', dir=FIXTURE.parent) as copy:
            copy.write(original.replace(b'\n', b'\r\n'))
            copy.flush()
            assert 'Proof tokens' in run(copy.name, ['--apply'])
            expected_source = original.decode().replace(json.loads(expected[1]['content'])['original_proof'], PROOF)
            accepted = expected_source.replace('\n', '\r\n').encode()
            assert Path(copy.name).read_bytes() == accepted
            assert 'No verified improvement' in run(copy.name, ['--apply'])
            assert Path(copy.name).read_bytes() == accepted

        response[:] = [None, 'by sorry', PROOF, 'by grind', PROOF]
        start = len(calls)
        with tempfile.NamedTemporaryFile(prefix='Optimizer', suffix='.lean', dir=FIXTURE.parent) as copy:
            copy.write(original)
            copy.flush()
            batch_prompt = json.loads(run(copy.name, ['--dump-prompt']))['messages']
            summary = run(copy.name, ['--apply'], candidates=32)
            assert '31/32 responses, 3 distinct candidates, 2 verified improvements' in summary, summary
            assert Path(copy.name).read_text() == original.decode().replace(
                json.loads(expected[1]['content'])['original_proof'], 'by grind')
        batch = calls[start:]
        assert len(batch) == 32 and 1 < peak <= 8
        assert all(r['temperature'] == 0.7 and r['top_p'] == 0.9 and r['input'] == batch_prompt for r in batch)
        response[:] = ['by sorry']
        assert '0 verified improvements' in run(FIXTURE, candidates=2)
        response[:] = [None]
        try:
            run(FIXTURE, candidates=2)
        except subprocess.CalledProcessError:
            pass
        else:
            raise AssertionError('All requests failed, expected a model error')

        response[:] = ['by sorry', PROOF, 'by grind', PROOF]
        sampled_env = dict(env, LLMLEAN_PROVIDER='local', LLMLEAN_OPTIMIZE_CANDIDATES='4',
                           LLMLEAN_OPTIMIZE_RETRIEVAL_TOKENS='1024')
        with contextlib.closing(Session(sampled_env)) as lsp:
            uri = FIXTURE.as_uri()
            lsp.send('initialize', dict(processId=os.getpid(), rootUri=ROOT.as_uri(), capabilities={
                'textDocument': {'codeAction': {'dataSupport': True, 'resolveSupport': {'properties': ['edit']}}},
                'workspace': {'workspaceEdit': {'documentChanges': True}}
            }), 1)
            lsp.send('initialized', {})
            buffer = original.decode().replace('have hp', '-- Unsaved proof comment\n  have hp')
            lsp.send('textDocument/didOpen', dict(textDocument=dict(uri=uri, languageId='lean4', version=7, text=buffer)))
            pos = dict(line=next(i for i,x in enumerate(buffer.splitlines()) if 'have hp' in x), character=4)
            params = dict(textDocument=dict(uri=uri), range=dict(start=pos,end=pos), context=dict(diagnostics=[]))
            prior = len(calls)
            actions = lsp.send('textDocument/codeAction', params, 2)
            action = next(a for a in actions if a['title'] == 'LLMLean: Optimize proof')
            assert len(calls) == prior
            resolved = lsp.send('codeAction/resolve', action, 3)
            assert 'Unsaved proof comment' in json.loads(calls[-1]['input'][1]['content'])['original_proof']
            edit = resolved['edit']
            change, = edit['documentChanges']
            assert change['textDocument'] == {'uri': uri, 'version': 7}
            one, = change['edits']
            assert len(calls) == prior + 4
            assert one['newText'] == 'by grind' and edit['changeAnnotations'][one['annotationId']]['needsConfirmation']
            assert all(json.loads(call['input'][1]['content'])['additional_available_lemmas'] for call in calls[prior:])
            session = lsp.send('$/lean/rpc/connect', {'uri': uri}, 4)['sessionId']
            status = lsp.send('$/lean/rpc/call', dict(textDocument=dict(uri=uri), position=pos,
                sessionId=session, method='LLMlean.Optimize.Panel.status', params=pos), 5)
            samples = '4/4 responses, 3 distinct candidates, 2 verified improvements'
            assert status['metrics']['samples'] == samples
            assert edit['changeAnnotations'][one['annotationId']]['label'].endswith(samples)
            assert FIXTURE.read_bytes() == original
        check_demo_infoview(dict(env, LLMLEAN_PROVIDER='local'), calls)
        demo = ROOT / 'LLMleanDemo/Demo.lean'
        dump = subprocess.check_output(cli + [str(demo), '--decl', 'Demo.swap', '--dump-prompt'],
                                       cwd=ROOT, env=env, text=True)
        assert comparable_messages(calls[-1]['input']) == comparable_messages(json.loads(dump)['messages'])
        check_editor_scope(dict(env, LLMLEAN_PROVIDER='local'), calls, response)
        server.shutdown()
    print('Passed provider message parity, preview, verified apply, rejection and unsaved LSP action.')


if __name__ == '__main__':
    test()
