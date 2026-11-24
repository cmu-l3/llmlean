import * as React from 'react'
import { useRpcSession, useServerNotificationEffect, useClientNotificationEffect } from '@leanprover/infoview'

const h = React.createElement
const method = 'LLMlean.Optimize.Panel.'

export default function OptimizerPanel({ pos }) {
  const session = useRpcSession()
  const { uri, line, character } = pos
  const [view, setView] = React.useState(null)
  const [now, setNow] = React.useState(Date.now)
  const revision = React.useRef(0)
  const version = React.useRef(null)

  const refresh = React.useCallback(async () => {
    const request = ++revision.current
    try {
      const state = await session.call(method + 'status', { line, character })
      if (request !== revision.current) return
      if (!state || (version.current !== null && state.version < version.current)) {
        setView(null)
        return
      }
      setView({ ...state, session, uri, line, character, received: Date.now() })
    } catch {
      if (request === revision.current) setView(null)
    }
  }, [session, uri, line, character])

  useServerNotificationEffect('$/llmlean/optimizeChanged', event => {
    if (event.uri === uri) void refresh()
  }, [uri, refresh])
  useClientNotificationEffect('textDocument/didChange', event => {
    if (event.textDocument.uri === uri) {
      version.current = event.textDocument.version
      revision.current++
      setView(null)
    }
  }, [uri])
  React.useEffect(() => { version.current = null }, [session, uri])
  React.useEffect(() => {
    void refresh()
    return () => { revision.current++ }
  }, [refresh])

  const waiting = view?.waitMs != null
  React.useEffect(() => {
    if (!waiting) return
    setNow(Date.now())
    const timer = setInterval(() => setNow(Date.now()), 500)
    return () => clearInterval(timer)
  }, [waiting])

  if (!view || view.session !== session || view.uri !== uri || view.line !== line || view.character !== character) return null
  const counts = view.metrics
  const title = view.finished ? view.name + (counts ? ' · Verified by Lean' : '') : 'Optimizing ' + view.name
  const elapsed = waiting ? ' · ' + Math.floor((view.waitMs + Math.max(0, now - view.received)) / 1000) + 's' : ''
  const action = view.canReview ? ['Review change', 'review'] : waiting ? ['Cancel', 'cancelWait'] : null
  const button = action && h('button', {
    type: 'button',
    onClick: () => session.call(method + action[1], { pos: { line, character }, id: view.id }).then(refresh, refresh),
  }, action[0])

  return h('section', { style: { margin: '0.5em 0' } },
    h('strong', null, title),
    view.message && view.message !== 'Verified by Lean' && h('div', null, view.message + elapsed),
    counts && h('div', null, 'Proof tokens ', h('strong', null, counts.tokens.join(' → ')),
      ' · Explicitly named lemmas ', h('strong', null, counts.lemmas.map(n => n ?? 'unknown').join(' → '))),
    button)
}
