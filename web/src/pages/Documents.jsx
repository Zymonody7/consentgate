import { useMemo, useState } from 'react'
import { Search, ChevronDown } from 'lucide-react'
import { Badge } from '../components/ui/badge'
import { Card } from '../components/ui/card'
import { useJson } from '../lib/data'

const PROV = {
  TEXT: { kind: 'outline', note: 'typed or exported text' },
  EMBEDDED: { kind: 'escalate', note: 'arrived inside the HL7 message' },
  OCR: { kind: 'untrusted', note: 'machine transcript' },
}

export default function Documents() {
  const { data } = useJson('data/documents.json', [])
  const docs = Array.isArray(data) ? data : []
  const [q, setQ] = useState('')
  const [open, setOpen] = useState(null)

  const rows = useMemo(() => {
    const n = q.trim().toLowerCase()
    return docs.filter((d) => !n || `${d.mrn} ${d.docType} ${d.source}`.toLowerCase().includes(n))
  }, [docs, q])

  return (
    <div className="mx-auto max-w-5xl p-6">
      <div className="flex items-center gap-3">
        <p className="text-sm text-muted-foreground">
          The paperwork the gate verifies against. Provenance says where the text came from.
        </p>
        <div className="relative ml-auto">
          <Search className="pointer-events-none absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Filter by MRN or document"
            className="h-9 w-64 rounded-md border border-input bg-background pl-8 pr-3 text-sm outline-none focus:ring-2 focus:ring-ring focus:ring-offset-1 focus:ring-offset-background"
          />
        </div>
      </div>

      <div className="mt-4 space-y-2">
        {rows.map((d) => {
          const prov = PROV[d.provenance] || { kind: 'outline', note: '' }
          const isOpen = open === d.id
          return (
            <Card key={d.id} className="overflow-hidden">
              <button
                onClick={() => setOpen(isOpen ? null : d.id)}
                className="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-accent/40"
              >
                <span className="w-8 font-mono text-[11px] text-muted-foreground">#{d.id}</span>
                <span className="font-serif text-[15px]">{d.mrn}</span>
                <span className="text-xs text-muted-foreground">{d.docType}</span>
                <Badge kind={prov.kind}>{d.provenance || 'TEXT'}</Badge>
                <span className="min-w-0 flex-1 truncate text-xs text-muted-foreground">{d.source}</span>
                <span className="text-[11px] text-muted-foreground">{d.receivedOn}</span>
                <ChevronDown className={`h-4 w-4 text-muted-foreground transition-transform ${isOpen ? 'rotate-180' : ''}`} />
              </button>
              {isOpen && (
                <div className="border-t border-border bg-background px-4 py-3">
                  <div className="mb-2 text-[10.5px] uppercase tracking-[0.08em] text-muted-foreground">
                    Text the gate verifies · {prov.note}
                  </div>
                  <p className="max-w-[78ch] whitespace-pre-wrap font-serif text-[14.5px] leading-7">{d.body}</p>
                </div>
              )}
            </Card>
          )
        })}
        {rows.length === 0 && <p className="py-10 text-center text-sm text-muted-foreground">No documents match this filter.</p>}
      </div>
    </div>
  )
}
