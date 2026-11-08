import { Link } from 'react-router-dom'
import { ArrowRight, FileSearch, Gavel, ShieldCheck, CheckCircle2 } from 'lucide-react'
import { Card, CardContent, CardTitle } from '../components/ui/card'
import { DecisionBadge, Badge } from '../components/ui/badge'
import { useDecisions, deriveStats, hhmm } from '../lib/data'

const STEPS = [
  { icon: FileSearch, title: 'Read', body: 'The agent extracts findings from the paperwork: category, effect, recipient, validity, and the sentence that supports it.' },
  { icon: Gavel, title: 'Verify', body: 'The gate checks the quote against the document, the recipient, the validity date, revocation and 42 CFR Part 2 rules.' },
  { icon: ShieldCheck, title: 'Decide', body: 'The release list is computed from verified findings. The model has no decision field to write into.' },
  { icon: CheckCircle2, title: 'Record', body: 'The message is redacted and routed, and one audit row keeps the decision, scope and evidence.' },
]

export default function Overview() {
  const { decisions } = useDecisions()
  const stats = deriveStats(decisions)

  const items = [
    { label: 'requests', value: stats?.total ?? '—' },
    { label: 'categories withheld', value: stats ? (stats.redacted || 0) + (stats.denied || 0) : '—' },
    { label: 'need review', value: stats?.pendingReview ?? '—' },
    { label: 'unverified input', value: stats?.injectionFlagged ?? '—', warn: stats?.injectionFlagged > 0 },
  ]

  return (
    <div className="mx-auto max-w-5xl space-y-6 px-8 py-7">
      <div>
        <h2 className="text-[22px] font-semibold leading-tight tracking-tight">Disclosure review</h2>
        <p className="mt-1.5 max-w-2xl text-[13px] leading-relaxed text-muted-foreground">
          Requests are judged against the consent paperwork on file. Every release names the sentence it relies on. Synthetic data only.
        </p>
      </div>

      <div className="flex flex-wrap items-baseline gap-x-7 gap-y-3 border-y border-border py-3.5">
        {items.map((it) => (
          <div key={it.label} className="flex items-baseline gap-2">
            <span className={`text-[17px] font-medium tnum `}>{it.value}</span>
            <span className="text-[10.5px] uppercase tracking-[0.09em] text-muted-foreground">{it.label}</span>
          </div>
        ))}
        <Link to="/queue" className="ml-auto inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground">
          Open queue <ArrowRight className="h-3.5 w-3.5" />
        </Link>
      </div>

      <Card>
        <CardContent className="pt-5">
          <div className="mb-2 flex items-center justify-between">
            <CardTitle>Latest decisions</CardTitle>
          </div>
          {decisions.length === 0 && <p className="py-6 text-sm text-muted-foreground">No decisions yet. Drop an HL7 file into data/in.</p>}
          <ul className="divide-y divide-border">
            {decisions.slice(0, 7).map((d) => (
              <li key={d.id}>
                <Link to={`/decision/${d.id}`} className="-mx-2 flex items-center gap-3 rounded px-2 py-2 hover:bg-accent/50">
                  <span className="w-[78px] shrink-0 text-[14px] font-medium tnum">{d.mrn}</span>
                  <span className="min-w-0 flex-1 truncate text-[12.5px] text-muted-foreground">
                    {d.requestorOrg} · {d.purposeOfUse}
                  </span>
                  {d.injectionFlag ? <Badge kind="untrusted">unverified</Badge> : null}
                  {d.gateResult === 'OVERRIDDEN' ? <span className="text-[10.5px] text-escalate">overridden</span> : null}
                  <DecisionBadge decision={d.decision} />
                  <span className="w-9 text-right text-[11px] tnum text-muted-foreground">{hhmm(d.createdAt)}</span>
                </Link>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {STEPS.map(({ icon: Icon, title, body }) => (
          <div key={title}>
            <div className="mb-1.5 flex items-center gap-2 text-[10.5px] uppercase tracking-[0.09em] text-muted-foreground">
              <Icon className="h-3.5 w-3.5" />
            </div>
            <div className="text-[13px] font-medium">{title}</div>
            <p className="mt-1 text-[12.5px] leading-relaxed text-muted-foreground">{body}</p>
          </div>
        ))}
      </div>
    </div>
  )
}
