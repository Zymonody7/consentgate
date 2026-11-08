import { Card, CardContent } from '../components/ui/card'

const RULES = [
  {
    n: '01',
    title: 'The quote must exist',
    body: 'Each finding carries a sentence copied from the document. The gate looks for that sentence as a literal substring of the stored text. A paraphrase is rejected and the finding does not count.',
  },
  {
    n: '02',
    title: 'The quote must speak to the category',
    body: 'A real sentence can be copied out of a document and still be irrelevant. For SUBSTANCE_USE the quote has to contain language about substance use; for HIV, about HIV. A generic authorisation sentence cannot justify a protected category.',
  },
  {
    n: '03',
    title: 'The recipient and the date must cover the request',
    body: 'If the instrument names a recipient, the requestor has to be that recipient. If it carries an expiry and that date has passed, the finding is void.',
  },
  {
    n: '04',
    title: 'A later revocation wins',
    body: 'Findings are resolved by document date, latest wins. A grant followed by a later revocation is an override, not a contradiction. Two findings dated the same day that disagree escalate.',
  },
  {
    n: '05',
    title: 'Substance use needs a Part 2 consent',
    body: 'Whatever the extraction reports, if there is no 42 CFR Part 2 consent on file, SUBSTANCE_USE is withheld and the gate marks the row as overridden.',
  },
  {
    n: '06',
    title: 'A machine transcript is not the paper',
    body: 'Documents record where their text came from: TEXT, EMBEDDED (an attachment in the message) or OCR. A grant of SUBSTANCE_USE, HIV or GENETIC from an OCR transcript escalates for human verification of the scan.',
  },
]

export default function Rules() {
  return (
    <div className="mx-auto max-w-4xl p-6">
      <h2 className="font-serif text-2xl tracking-tight">How a decision is computed</h2>
      <p className="mt-1 max-w-2xl text-sm text-muted-foreground">
        The agent extracts. These six checks decide. Anything they cannot establish escalates to a human.
      </p>

      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        {RULES.map((r) => (
          <Card key={r.n}>
            <CardContent className="pt-5">
              <div className="font-mono text-[11px] text-muted-foreground">{r.n}</div>
              <div className="mt-1 text-sm font-medium">{r.title}</div>
              <p className="mt-1.5 text-[13px] leading-relaxed text-muted-foreground">{r.body}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="mt-6 overflow-hidden rounded-lg border border-border">
        <table className="w-full text-sm">
          <thead className="bg-muted/50 text-left text-[10.5px] uppercase tracking-[0.08em] text-muted-foreground">
            <tr>
              <th className="px-4 py-2.5 font-medium">Provenance</th>
              <th className="px-4 py-2.5 font-medium">What the gate does</th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-t border-border">
              <td className="px-4 py-3 font-mono text-xs">TEXT / EMBEDDED</td>
              <td className="px-4 py-3 text-muted-foreground">Verifies the quote and decides normally.</td>
            </tr>
            <tr className="border-t border-border">
              <td className="px-4 py-3 font-mono text-xs">OCR</td>
              <td className="px-4 py-3 text-muted-foreground">
                Verifies, but a grant of a protected category escalates for human verification.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  )
}
