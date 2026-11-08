import { useMemo, useState } from 'react'
import { Tabs, TabsList, TabsTrigger } from '../components/ui/tabs'
import { DecisionBadge, Badge } from '../components/ui/badge'
import { useJson } from '../lib/data'
import { cn } from '../lib/utils'

const SEG = {
  MSH: 'Message header',
  PID: 'Patient identification',
  OBR: 'Observation request',
  OBX: 'Observation / result',
  NTE: 'Notes and comments',
}

const LOINC = {
  '4548-4': 'GENERAL',
  '2160-0': 'GENERAL',
  '1975-2': 'GENERAL',
  '9459-0': 'SUBSTANCE_USE',
  '19270-4': 'SUBSTANCE_USE',
  '72166-2': 'MENTAL_HEALTH',
  '44249-1': 'MENTAL_HEALTH',
  '24467-3': 'HIV',
  '75622-1': 'HIV',
  '21667-1': 'GENETIC',
}

const FIELD = {
  MSH: {
    3: ['Sending application', 'Who sent the message.'],
    4: ['Sending facility', 'Source lab.'],
    5: ['Receiving application', 'The requestor. The gate matches this against the recipient named in the consent.'],
    6: ['Receiving facility', 'Purpose of use, e.g. TREATMENT.'],
    7: ['Date/time', 'Message timestamp.'],
    9: ['Message type', 'ORU^R01 = unsolicited observation result.'],
    10: ['Control ID', 'Keys the audit row.'],
    11: ['Processing ID'],
    12: ['Version', 'HL7 v2.5.1.'],
  },
  PID: { 3: ['Patient identifier', "MRN. Used to fetch this patient's consent documents."], 5: ['Patient name'], 7: ['Date of birth'], 8: ['Sex'] },
  OBR: { 4: ['Universal service ID', 'The order the results belong to.'], 7: ['Observation date/time'] },
  OBX: {
    2: ['Value type', 'NM = numeric, ED = encapsulated data (an attachment).'],
    3: ['Observation ID', 'LOINC code. ConsentGate maps it to a consent category.'],
    4: ['Sub-ID'],
    5: ['Value', 'The result itself. This is what gets replaced when withheld.'],
    6: ['Units'],
    8: ['Interpretation', 'H = high, N = normal.'],
    11: ['Status', 'F = final.'],
  },
}

export default function Reader() {
  const { data: messages } = useJson('data/messages.json', [])
  const { data: decisions } = useJson('data/decisions.json', [])
  const list = Array.isArray(messages) ? messages : []
  const [idx, setIdx] = useState(0)
  const [view, setView] = useState('reader')
  const [sel, setSel] = useState(null)

  const byRequest = useMemo(() => {
    const m = {}
    ;(Array.isArray(decisions) ? decisions : []).forEach((d) => (m[d.requestId] = d))
    return m
  }, [decisions])

  const msg = list[idx]
  if (!msg) {
    return <div className="p-10 text-sm text-muted-foreground">No sample messages found in data/samples.</div>
  }

  const segs = msg.text.split('\r').filter((s) => s.trim() !== '')
  const requestId = (segs[0] || '').split('|')[9] || ''
  const decision = byRequest[requestId]
  const withheld = (decision?.withheld || []).map((x) => String(x).toUpperCase())

  return (
    <div className="flex h-full flex-col">
      <div className="flex flex-wrap items-center gap-2 border-b border-border bg-card px-4 py-2.5">
        <Tabs value={String(idx)} onValueChange={(v) => { setIdx(+v); setSel(null) }}>
          <TabsList>
            {list.map((m, i) => (
              <TabsTrigger key={m.file} value={String(i)} className="font-mono text-[11px]">
                {m.file.replace('.hl7', '')}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <div className="ml-auto inline-flex overflow-hidden rounded-md border border-input">
          {['reader', 'raw'].map((v) => (
            <button
              key={v}
              onClick={() => setView(v)}
              className={cn('h-8 px-3 text-xs capitalize text-muted-foreground', view === v && 'bg-muted font-medium text-foreground')}
            >
              {v}
            </button>
          ))}
        </div>
      </div>

      <div className="grid min-h-0 flex-1 grid-cols-1 overflow-hidden lg:grid-cols-[minmax(0,1fr)_360px]">
        <div className="min-h-0 overflow-y-auto p-5">
          {decision && (
            <div className="mx-auto mb-4 flex max-w-3xl flex-wrap items-center gap-2 rounded-lg border border-border bg-card px-4 py-2.5">
              <span className="text-[10.5px] uppercase tracking-[0.08em] text-muted-foreground">Decision</span>
              <DecisionBadge decision={decision.decision} />
              {(decision.released || []).map((c) => (
                <span key={c} className="rounded border border-release bg-release-bg px-1.5 py-0.5 font-mono text-[11px] text-release">{c}</span>
              ))}
              {(decision.withheld || []).map((c) => (
                <span key={c} className="rounded border border-redact bg-redact-bg px-1.5 py-0.5 font-mono text-[11px] text-redact">{c}</span>
              ))}
              {decision.injectionFlag ? <Badge kind="untrusted">untrusted</Badge> : null}
              <span className="ml-auto font-mono text-[11px] text-muted-foreground">
                {decision.gateResult} · {decision.confidence} · {decision.latencyMs} ms
              </span>
            </div>
          )}

          {view === 'raw' ? (
            <pre className="mx-auto max-w-3xl overflow-x-auto rounded-lg border border-border bg-card p-4 font-mono text-[12.5px] leading-7 text-muted-foreground">
              {segs.join('\n')}
            </pre>
          ) : (
            <div className="mx-auto max-w-3xl space-y-2.5">
              {segs.map((seg, si) => {
                const id = seg.split('|')[0]
                const parts = seg.split('|')
                const isED = id === 'OBX' && parts[2] === 'ED'
                return (
                  <div key={si} className="overflow-hidden rounded-lg border border-border bg-card">
                    <div className="flex items-baseline gap-2 border-b border-border bg-muted/40 px-3.5 py-2">
                      <span className="font-mono text-xs font-bold tracking-wide">{id}</span>
                      <span className="text-xs text-muted-foreground">{SEG[id] || ''}</span>
                      <span className="ml-auto font-mono text-[10.5px] text-muted-foreground">
                        segment {si + 1} of {segs.length}
                      </span>
                    </div>
                    <div className="flex flex-wrap gap-1.5 p-3">
                      {parts.map((val, fi) => {
                        if (fi === 0) return null
                        const fnum = id === 'MSH' ? fi + 1 : fi
                        const spec = (FIELD[id] || {})[fnum]
                        const code = (parts[3] || '').split('^')[0]
                        const cat = id === 'OBX' ? LOINC[code] : null
                        const isWithheld = id === 'OBX' && fi === 5 && !isED && cat && withheld.includes(cat)
                        const key = `${si}:${fi}`
                        const active = sel === key
                        return (
                          <button
                            key={fi}
                            onClick={() => setSel(active ? null : key)}
                            className={cn(
                              'inline-flex max-w-full items-baseline gap-1.5 rounded border border-border bg-background px-2 py-1 font-mono text-xs hover:border-muted-foreground',
                              !val && 'opacity-45',
                              active && 'ring-2 ring-ring ring-offset-1 ring-offset-card',
                              isWithheld && 'border-redact bg-redact-bg text-redact',
                            )}
                          >
                            <span className="text-[9.5px] uppercase tracking-[0.05em] text-muted-foreground">
                              {spec ? spec[0] : `${id}-${fnum}`}
                            </span>
                            <span className="max-w-[42ch] truncate">{isED && fi === 5 ? `${val.slice(0, 42)}…` : val || '∅'}</span>
                          </button>
                        )
                      })}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>

        <aside className="hidden min-h-0 overflow-y-auto border-l border-border bg-card p-5 lg:block">
          <Anno segs={segs} sel={sel} decision={decision} />
        </aside>
      </div>

      {sel && (
        <div className="border-t border-border bg-card p-4 lg:hidden">
          <Anno segs={segs} sel={sel} decision={decision} />
        </div>
      )}
    </div>
  )
}

function Anno({ segs, sel, decision }) {
  if (!sel) {
    return (
      <>
        <h3 className="font-serif text-xl">Fields</h3>
        <p className="mt-1 text-xs text-muted-foreground">Select any field in the message to see what it is and what ConsentGate did with it.</p>
      </>
    )
  }
  const [si, fi] = sel.split(':').map(Number)
  const seg = segs[si]
  const parts = seg.split('|')
  const id = parts[0]
  const fnum = id === 'MSH' ? fi + 1 : fi
  const val = parts[fi] || ''
  const spec = (FIELD[id] || {})[fnum] || [`${id}-${fnum}`, '']

  let used = ''
  if (id === 'MSH' && fnum === 5) used = 'Used as the requestor. The gate compares it with the recipient named in each consent instrument.'
  else if (id === 'MSH' && fnum === 6) used = 'Used as the purpose of use. A purpose the patient did not authorise is a reason to withhold.'
  else if (id === 'MSH' && fnum === 10) used = 'Recorded as the request ID on the audit row and in the output file name.'
  else if (id === 'PID' && fi === 3) used = "Used to fetch the patient's consent documents and structured consent rows."
  else if (id === 'OBX' && fi === 3) {
    const code = (val || '').split('^')[0]
    const cat = LOINC[code]
    used = cat
      ? `LOINC ${code} maps to consent category ${cat}. That mapping decides which rule applies.`
      : 'No mapping in the demonstration code set; treated as GENERAL.'
  } else if (id === 'OBX' && fi === 5) {
    if (parts[2] === 'ED') {
      used = 'Encapsulated data: source^type^subtype^encoding^payload. The production decodes it, stores it as a consent document with provenance EMBEDDED, and the agent can cite it in the same decision.'
    } else {
      const code = (parts[3] || '').split('^')[0]
      const cat = LOINC[code]
      const w = (decision?.withheld || []).map((x) => String(x).toUpperCase())
      used = cat && w.includes(cat)
        ? `Category ${cat} was withheld, so this value is replaced with [WITHHELD: ${cat}] in the outbound message. The segment itself stays.`
        : 'This value is released unchanged.'
    }
  }

  return (
    <div>
      <div className="font-mono text-[11.5px] text-muted-foreground">
        {id}-{fnum}
      </div>
      <div className="mt-1 text-[15px]">{spec[0]}</div>
      <dl className="mt-3 grid grid-cols-[64px_1fr] gap-x-2 gap-y-1.5 text-xs">
        <dt className="text-[10px] uppercase tracking-[0.05em] text-muted-foreground">Field</dt>
        <dd className="font-mono break-all">{id}-{fnum}</dd>
        <dt className="text-[10px] uppercase tracking-[0.05em] text-muted-foreground">Value</dt>
        <dd className="font-mono break-all">{val ? val.slice(0, 220) : 'empty'}</dd>
      </dl>
      {spec[1] ? <p className="mt-2.5 text-xs text-muted-foreground">{spec[1]}</p> : null}
      {used ? <div className="mt-3 rounded-md border border-border bg-background p-3 text-xs text-muted-foreground">{used}</div> : null}
    </div>
  )
}
