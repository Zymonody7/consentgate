import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search } from 'lucide-react'
import { Tabs, TabsList, TabsTrigger } from '../components/ui/tabs'
import { DecisionBadge, Badge } from '../components/ui/badge'
import { useDecisions, hhmm } from '../lib/data'
import { cn } from '../lib/utils'

const FILTERS = [
  { id: 'all', label: 'All' },
  { id: 'escalate', label: 'Awaiting review' },
  { id: 'untrusted', label: 'Unverified' },
  { id: 'release', label: 'Release' },
  { id: 'redact', label: 'Redact' },
  { id: 'deny', label: 'Deny' },
]

export default function Queue() {
  const { decisions } = useDecisions()
  const navigate = useNavigate()
  const [filter, setFilter] = useState('all')
  const [q, setQ] = useState('')
  const [active, setActive] = useState(null)

  const rows = useMemo(() => {
    const needle = q.trim().toLowerCase()
    return decisions.filter((d) => {
      const k = String(d.decision || '').toLowerCase()
      if (filter === 'escalate' && k !== 'escalate') return false
      if (filter === 'untrusted' && !d.injectionFlag) return false
      if (['release', 'redact', 'deny'].includes(filter) && k !== filter) return false
      if (needle && !`${d.mrn} ${d.requestId} ${d.requestorOrg}`.toLowerCase().includes(needle)) return false
      return true
    })
  }, [decisions, filter, q])

  useEffect(() => {
    const onKey = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return
      const idx = rows.findIndex((r) => String(r.id) === active)
      if (e.key === 'j' || e.key === 'ArrowDown') {
        e.preventDefault()
        const next = rows[Math.min((idx < 0 ? -1 : idx) + 1, rows.length - 1)]
        if (next) setActive(String(next.id))
      } else if (e.key === 'k' || e.key === 'ArrowUp') {
        e.preventDefault()
        const next = rows[Math.max((idx < 0 ? 0 : idx) - 1, 0)]
        if (next) setActive(String(next.id))
      } else if (e.key === 'Enter' && active) {
        navigate(`/decision/${active}`)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [rows, active, navigate])


  return (
    <div className="mx-auto max-w-5xl p-6">
      <div className="flex flex-wrap items-center gap-3">
        <Tabs value={filter} onValueChange={setFilter}>
          <TabsList>
            {FILTERS.map((f) => (
              <TabsTrigger key={f.id} value={f.id}>
                {f.label}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <span className="text-[11px] tnum text-muted-foreground">{rows.length} of {decisions.length}</span>
        <div className="relative ml-auto">
          <Search className="pointer-events-none absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search MRN or request"
            className="h-9 w-64 rounded-md border border-input bg-background pl-8 pr-3 text-sm outline-none focus:ring-2 focus:ring-ring focus:ring-offset-1 focus:ring-offset-background"
          />
        </div>
      </div>

      <div className="mt-4 overflow-hidden rounded-lg border border-border bg-card">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-[10.5px] uppercase tracking-[0.08em] text-muted-foreground">
              <th className="px-4 py-2 font-medium">Patient</th>
              <th className="px-4 py-2.5 font-medium">Requestor</th>
              <th className="px-4 py-2.5 font-medium">Purpose</th>
              <th className="px-4 py-2.5 font-medium">Gate</th>
              <th className="px-4 py-2.5 font-medium">Decision</th>
              <th className="px-4 py-2.5 text-right font-medium">Time</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((d) => (
              <tr
                key={d.id}
                tabIndex={0}
                onClick={() => navigate(`/decision/${d.id}`)}
                onMouseEnter={() => setActive(String(d.id))}
                onKeyDown={(e) => e.key === 'Enter' && navigate(`/decision/${d.id}`)}
                className={cn(
                  'cursor-pointer border-b border-l-[3px] border-border last:border-0 hover:bg-accent/50 focus:bg-accent/50 focus:outline-none',
                  d.decision === 'RELEASE' && 'border-l-release',
                  d.decision === 'REDACT' && 'border-l-redact',
                  d.decision === 'DENY' && 'border-l-deny',
                  d.decision === 'ESCALATE' && 'border-l-escalate',
                  active === String(d.id) && 'bg-accent/50',
                )}
              >
                <td className="px-4 py-2.5">
                  <span className="text-[14px] font-medium tnum">{d.mrn}</span>
                  {d.injectionFlag ? (
                    <span className="ml-2 align-middle">
                      <Badge kind="untrusted">unverified</Badge>
                    </span>
                  ) : null}
                </td>
                <td className="px-4 py-2.5 text-muted-foreground">{d.requestorOrg}</td>
                <td className="max-w-[220px] truncate px-4 py-2.5 text-muted-foreground">{d.purposeOfUse}</td>
                <td className="px-4 py-2.5">
                  <span className={cn('text-xs', d.gateResult === 'OVERRIDDEN' ? 'text-escalate' : 'text-muted-foreground')}>
                    {d.gateResult === 'OVERRIDDEN' ? 'overridden' : 'passed'}
                  </span>
                </td>
                <td className="px-4 py-2.5">
                  <DecisionBadge decision={d.decision} />
                </td>
                <td className="px-4 py-2.5 text-right text-xs tnum text-muted-foreground">{hhmm(d.createdAt)}</td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-12 text-center text-sm text-muted-foreground">
                  No decisions match this view.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
