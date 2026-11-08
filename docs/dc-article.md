# ConsentGate: Verify the Sentence, Not the Conclusion

## The decision we automated

An outside organisation asks for a patient's lab results, as an HL7 v2.5.1 ORU^R01 file in a watched directory. The justification sits in the consent file: an authorisation letter, a revocation posted nine days later, a 42 CFR Part 2 consent naming one clinic, occasionally a court order naming one genetic result.

A person reads it all and decides what may leave the building. The reasoning is usually a free-text note.

ConsentGate is an IRIS Interoperability production that automates the reading and checks, not the judgment. The message enters through `EnsLib.File.PassthroughService`, lands in `ConsentGate.BP.Disclosure`, and leaves as `RELEASE`, `REDACT`, `DENY` or `ESCALATE`. A redaction keeps the OBX segment and replaces its value, so the recipient can see something was withheld:

```
OBX|3|NM|9459-0^Ethyl glucuronide, urine||[WITHHELD: SUBSTANCE_USE]|ng/mL||H|||F
```

Every request writes a row to `ConsentGate_Data.Decision` before routing. Decision, released and withheld categories, evidence, gate result, injection flag and latency are columns, not prose.

## The split: findings in, disposition out

The agent is a `%AI.Agent` with three read-only tools. Its contract has no `decision` field. Each finding says: this document, this category, grant or deny, this recipient, valid until this date, and here is the sentence.

```
{
  "findings": [
    {
      "docId": 4,
      "category": "SUBSTANCE_USE",
      "effect": "GRANT",
      "recipient": "ORG-CLINIC",
      "validUntil": "2027-08-30",
      "quote": "verbatim sentence from that document"
    }
  ],
  "rationale": "one or two sentences",
  "confidence": 0.0-1.0
}
```

`findings[]` is the entire contract. There is nowhere to write "decision: RELEASE", so prompt injection, drift or a confidently wrong model has no field in which to emit a disposition. If one sends a decision anyway, `Gate.Apply` never reads it.

The gate then does five things, in this order:

1. `quote` must be a literal substring of the cited document's `Body`.
2. The quote must contain language that speaks to the category. A real sentence can still be irrelevant to the category it is used to justify.
3. Recipient and validity must cover this request.
4. A later revocation voids every grant.
5. `SUBSTANCE_USE` needs a 42 CFR Part 2 consent on file, whatever the extraction says.

The verification chain in `ConsentGate.Policy.Gate` is one `If/ElseIf`:

```objectscript
} ElseIf $FIND(doc.Body, quote) = 0 {
    Set why = "quote not found verbatim in document "_docId
} ElseIf '..QuoteSpeaksTo(quote, category) {
    Set why = "quote does not mention anything about "_category
} ElseIf (validUntil '= "") && (validUntil < today) {
    Set why = "instrument expired on "_validUntil
} ElseIf (recipient '= "") && ($ZCONVERT(recipient, "U") '= $ZCONVERT(requestorOrg, "U")) {
    Set why = "instrument names a different recipient ("_recipient_")"
}
```

A rejected finding is appended to `notes` and sets `gate = "OVERRIDDEN"`. If none survives, the disposition is `ESCALATE` and nothing is released; otherwise the category is withheld. The final decision comes from the verified map, not the model's rationale:

```objectscript
If latestEff.%Get(cat) = "GRANT" {
    Do result.release.%Push(cat)
} Else {
    Do result.withhold.%Push(cat)
}
```

Silence is not permission. Contradiction is not a decision. Unparseable output is escalated without being acted on.

## The bug a live model found

Our first contradiction rule was wrong. We collected verified findings into two sets, `granted` and `denied`, and escalated if a category appeared in both:

```objectscript
If (granted.%Get(cat) = 1) && (denied.%Get(cat) = 1) Set conflicted = 1
```

For patient CG-0002 this fired on an ordinary sequence: an authorisation received 2026-09-14, a revocation received 2026-10-28. A live DeepSeek run reported a `GRANT` from the first and a `DENY` from the second, both with correct verbatim quotes. The gate escalated a case whose answer was `DENY`.

The model was right. A later denial is an override, not an ambiguity; the document date distinguishes them. The gate now keeps the latest instrument per category and escalates only when same-day findings disagree:

```objectscript
Set prior = latestDate.%Get(category)
If (prior = "") || (docDate > prior) {
    Do latestDate.%Set(category, docDate)
    Do latestEff.%Set(category, effect)
} ElseIf (docDate = prior) && (effect '= latestEff.%Get(category)) {
    Set conflicted = 1
}
```

`docDate` is the document's `ReceivedOn`, not the `validUntil` the model reported. Validity is a claim to verify; receipt date is a fact on the row. Two findings dated the same day that disagree still escalate; there is no later instrument to prefer.

The agent was not the weak part. The policy encoded a plausible rule that was false; a real pair of correct citations exposed it.

## The harness

`eval/cases.json` holds ten consent situations with ground-truth dispositions, each paired with a model output. `ConsentGate.Eval.Harness` resolves document references in the running database, builds the JSON the agent would return, and calls `Gate.Apply`. No API key is needed.

They cover: an authorisation that expressly excludes a category; a fabricated quote; a real quote used for the wrong category; a revocation that voids a valid grant; expiry; a Part 2 consent that releases substance use; a Part 2 consent naming another recipient; two same-document findings that disagree; no findings; and a court order covering the genetic result it names.

The harness reports decision match and disposition-plus-scope match, both 10/10 on the current gate.

It feeds fixed model outputs into the gate. It measures the gate's handling of those outputs, including four adversarial ones. It does not measure the model: not extraction accuracy, not whether a live model would produce those findings. Production uses `deepseek-chat`; the harness is what a reviewer can reproduce without a key. Ten cases is a regression test, not a benchmark.

## A note for IRIS developers: no HL7 schema tables

The community IRIS for Health image does not ship the HL7 v2 schema tables. `^EnsHL7` is empty, so `EnsLib.HL7.Message` parses a message into a single MSH segment and `GetValueAt` returns nothing useful. A disclosure decision should not depend on a licensed schema library, so `ConsentGate.BP.Disclosure` reads the ORU^R01 as text and extracts the fields it needs:

```objectscript
Set segId = $PIECE(seg, "|", 1)
If segId = "MSH" {
    Set org = $PIECE(seg, "|", 5)
    Set purpose = $PIECE(seg, "|", 6)
    Set reqId = $PIECE(seg, "|", 10)
}
If segId = "PID" Set mrn = $PIECE(seg, "|", 4)
```

OBX-3 observation codes map to categories through `ConsentGate.Data.CodeMap`.

This is not a general HL7 parser. It handles the fields the gate needs, and redaction rewrites OBX-5 in place. With schema tables, `EnsLib.HL7.Message` is the better choice; the gate does not care which produced the segments.

## What we do not claim

- Three rules, one jurisdiction: authorisation scope and recipient, revocation precedence, Part 2 consent. This demonstrates a pattern, not a compliance product.
- Synthetic data only. No real PHI is in the repository, the seeds or the evaluation cases.
- The category keywords in `QuoteSpeaksTo` are a heuristic list. A production system would bind them to a maintained terminology; the check is a substring search, not natural-language inference.
- Quote verification is exact substring matching. OCR noise, reflowed PDFs and smart quotes would need normalisation first.
- Ten evaluation cases, written by us, with model outputs written by us.

The claim we make is narrower: the model's conclusion is not an input. The agent reads, the gate checks the sentence, and nothing leaves on the model's opinion.


## Paperwork that is not text

An `OBX` with value type `ED` carries an authorisation as a base64 attachment inside the
message. The production decodes it, stores it as a consent document, and the agent can
cite it in the same decision. Every document records whether the text the gate verifies
against came from TEXT, an EMBEDDED attachment, or an OCR transcript; a protected category
granted from an OCR transcript escalates.
