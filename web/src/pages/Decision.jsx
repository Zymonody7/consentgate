import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowLeft, Check, X, ExternalLink } from 'lucide-react'
import { Card, CardContent } from '../components/ui/card'
import { Badge, DecisionBadge } from '../components/ui/badge'
import { useDecisions, useJson } from '../lib/data'

const VERDICT = {
  RELEASE: 'Release',
  REDACT: 'Redact',
  DENY: 'Deny',
  ESCALATE: 'Escalate',
}

function verdictLine(d) {
  const rel = (d.released || []).length
  const wh = (d.withheld || []).length
  const k = String(d.decision || '').toUpperCase()
  let line =
    k === 'RELEASE'
      ? 'Every requested category is permitted by the paperwork on file.'
      : k === 'REDACT'
        ? `${rel} of ${rel + wh} categories permitted; ${wh} withheld.`
        : k === 'DENY'
          ? 'No requested category is permitted.'
          : 'The evidence did not settle the question; routed for human review.'
  if (d.gateResult === 'OVERRIDDEN' && k !== 'ESCALATE') line += " The gate overrode the model's proposal."
  return line
}

export default function Decision() {
  const { id } = useParams()
  const { decisions } = useDecisions()
  const { data: docs } = useJson('data/documents.json', [])
  const [cat, setCat] = useState('')
  useEffect(() => setCat(''), [id])

  const d = decisions.find((x) => String(x.id) === String(id))
  if (!d) {
    return (
      <div className="mx-auto max-w-3xl p-10 text-sm text-muted-foreground">
        <Link to="/queue" className="inline-flex items-center gap-1.5 hover:text-foreground">
          <ArrowLeft className="h-4 w-4" /> Back to the queue
        </Link>
        <p className="mt-6">That decision is not in this snapshot.</p>
      </div>
    )
  }

  const k = String(d.decision || '').toUpperCase()
  const tone = { RELEASE: 'text-release', REDACT: 'text-redact', DENY: 'text-deny', ESCALATE: 'text-escalate' }[k] || ''
  const evidence = (d.evidence || []).filter((e) => !cat || String(e.category).toUpperCase() === cat)
  const docById = Object.fromEntries((Array.isArray(docs) ? docs : []).map((x) => [String(x.id), x]))

  const chip = (c, kind) => {
    const on = cat === String(c).toUpperCase()
    return (
      <button
        key={c}
        onClick={() => setCat(on ? '' : String(c).toUpperCase())}
        className={`rounded border px-1.5 py-0.5 font-mono text-[11px] transition-colors ${
          kind === 'rel' ? 'border-release bg-release-bg text-release' : 'border-redact bg-redact-bg text-redact'
        } ${on ? 'ring-2 ring-ring ring-offset-1 ring-offset-card' : ''}`}
      >
        {c}
      </button>
    )
  }

  return (
    <div className="mx-auto max-w-4xl space-y-4 p-6">
      <Link to="/queue" className="inline-flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground">
        <ArrowLeft className="h-3.5 w-3.5" /> Queue
      </Link>

      <Card>
        <div className="flex flex-wrap items-start gap-4 border-b border-border p-6">
          <div className="min-w-0 flex-1">
            <div className={`font-serif text-3xl tracking-tight ${tone}`}>{VERDICT[k] || k}</div>
            <p className="mt-1.5 max-w-xl text-sm text-muted-foreground">{verdictLine(d)}</p>
          </div>
          <div className="flex flex-col items-end gap-1.5">
            <Badge kind="outline">{d.gateResult === 'OVERRIDDEN' ? 'Gate overridden' : d.gateResult === 'UNPARSEABLE' ? 'Output unparseable' : 'Gate passed'}</Badge>
            {d.injectionFlag ? <Badge kind="untrusted">Unverified input</Badge> : null}
          </div>
        </div>

        <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1 border-b border-border px-6 py-4">
          <span className="font-serif text-xl">{d.mrn}</span>
          <span className="text-sm text-muted-foreground">
            {d.requestorOrg} · {d.purposeOfUse}
          </span>
          <span className="ml-auto font-mono text-[11px] text-muted-foreground">
            {d.requestId} · {d.createdAt}
          </span>
        </div>

        <div className="border-b border-border px-6 py-5">
          <SectionLabel>Scope</SectionLabel>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="rounded-md border border-border bg-background p-3">
              <div className="mb-2 text-[10.5px] uppercase tracking-[0.08em] text-muted-foreground">
                Released ({(d.released || []).length})
              </div>
              <div className="flex flex-wrap gap-1.5">
                {(d.released || []).length ? d.released.map((c) => chip(c, 'rel')) : <span className="text-xs text-muted-foreground">None</span>}
              </div>
            </div>
            <div className="rounded-md border border-border bg-background p-3">
              <div className="mb-2 text-[10.5px] uppercase tracking-[0.08em] text-muted-foreground">
                Withheld ({(d.withheld || []).length})
              </div>
              <div className="flex flex-wrap gap-1.5">
                {(d.withheld || []).length ? d.withheld.map((c) => chip(c, 'wh')) : <span className="text-xs text-muted-foreground">None</span>}
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4 border-b border-border px-6 py-5 sm:grid-cols-4">
          {[
            ['Model', d.model || '—'],
            ['Latency', d.latencyMs != null ? `${d.latencyMs} ms` : '—'],
            ['Confidence', d.confidence || '—'],
            ['Decision', k],
          ].map(([label, value]) => (
            <div key={label}>
              <div className="text-[10.5px] uppercase tracking-[0.08em] text-muted-foreground">{label}</div>
              <div className="mt-1 font-mono text-[12.5px]">{value}</div>
            </div>
          ))}
        </div>

        <div className="border-b border-border px-6 py-5">
          <SectionLabel>Rationale</SectionLabel>
          <p className="max-w-[70ch] text-sm leading-relaxed">{d.rationale || 'No rationale recorded.'}</p>
        </div>

        <div className="px-6 py-5">
          <SectionLabel>
            Evidence{cat ? ` · ${cat} only` : ''}
          </SectionLabel>
          <div className="space-y-3">
            {evidence.map((e, i) => {
              const ok = e.verified === 1 || e.verified === true
              return (
                <div key={i} className="overflow-hidden rounded-md border border-border">
                  <div className="flex flex-wrap items-center gap-2 border-b border-border bg-background px-3.5 py-2">
                    <span className="font-mono text-[11px] text-muted-foreground">Document {e.docId}</span>
                    {docById[String(e.docId)] ? (
                      <span className="text-[11px] text-muted-foreground">
                        {docById[String(e.docId)].docType} · {docById[String(e.docId)].source}
                      </span>
                    ) : null}
                    <span className="font-mono text-[10.5px] text-muted-foreground before:mx-1.5 before:content-['·']">{e.category}</span>
                    <span className="font-mono text-[10.5px] text-muted-foreground before:mx-1.5 before:content-['·']">{e.effect}</span>
                    {e.provenance ? <span className="font-mono text-[10.5px] text-muted-foreground before:mx-1.5 before:content-['·']">{e.provenance}</span> : null}
                    <span className="ml-auto">
                      {ok ? (
                        <span className="inline-flex items-center gap-1 rounded border border-release px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-[0.05em] text-release">
                          <Check className="h-3 w-3" /> Verified
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 rounded border border-deny px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-[0.05em] text-deny">
                          <X className="h-3 w-3" /> Not found
                        </span>
                      )}
                    </span>
                  </div>
                  <blockquote className="bg-card px-4 py-4 font-serif text-[16px] leading-7">
                    <span className="mr-2 font-mono text-[10.5px] align-top text-muted-foreground">[Q{i + 1}]</span>
                    “{e.quote}”
                  </blockquote>
                </div>
              )
            })}
            {evidence.length === 0 && <p className="text-xs text-muted-foreground">No evidence recorded for this view.</p>}
          </div>

          <p className="mt-4 rounded-md border border-dashed border-border px-3.5 py-2.5 text-[12px] text-muted-foreground">
            Reviews are recorded through the authenticated API at <span className="font-mono">/consentgate/api/review</span>.
          </p>
        </div>
      </Card>

      <div className="flex justify-end">
        <Link to="/reader" className="inline-flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground">
          Look at the message itself <ExternalLink className="h-3.5 w-3.5" />
        </Link>
      </div>
    </div>
  )
}

function SectionLabel({ children }) {
  return <div className="mb-2.5 text-[10.5px] font-medium uppercase tracking-[0.11em] text-muted-foreground">{children}</div>
}
