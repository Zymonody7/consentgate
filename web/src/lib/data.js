import { useEffect, useState } from 'react'

export function useJson(path, fallback) {
  const [data, setData] = useState(fallback)
  const [error, setError] = useState(null)

  useEffect(() => {
    let live = true
    fetch(path, { cache: 'no-store' })
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`)
        return r.json()
      })
      .then((d) => live && setData(d))
      .catch((e) => live && setError(e.message))
    return () => {
      live = false
    }
  }, [path])

  return { data, error }
}

export function useDecisions() {
  const { data, error } = useJson('data/decisions.json', [])
  return { decisions: Array.isArray(data) ? data : [], error }
}

export function useStats() {
  return useJson('data/stats.json', null)
}

export function hhmm(iso) {
  const m = String(iso || '').match(/(\d{2}:\d{2})/)
  return m ? m[1] : '--'
}

export function decisionWord(d) {
  return { RELEASE: 'Release', REDACT: 'Redact', DENY: 'Deny', ESCALATE: 'Escalate' }[String(d || '').toUpperCase()] || d
}

export function deriveStats(decisions) {
  const list = Array.isArray(decisions) ? decisions : []
  const k = (d) => String(d.decision || '').toUpperCase()
  return {
    total: list.length,
    released: list.filter((d) => k(d) === 'RELEASE').length,
    redacted: list.filter((d) => k(d) === 'REDACT').length,
    denied: list.filter((d) => k(d) === 'DENY').length,
    escalated: list.filter((d) => k(d) === 'ESCALATE').length,
    pendingReview: list.filter(
      (d) => k(d) === 'ESCALATE' && !String(d.gateResult || '').startsWith('REVIEWED'),
    ).length,
    injectionFlagged: list.filter((d) => d.injectionFlag).length,
  }
}
