# ConsentGate

**A consent-aware HL7 disclosure gate built on InterSystems IRIS Interoperability and IRIS AI Hub.**

An outside organisation asks for a patient's lab results. Someone has to read the
paperwork — the authorisation letter, the revocation that arrived nine days later,
the 42 CFR Part 2 consent, the court order — and decide what may leave the building.
Today that decision is made by a person under time pressure, and the reasoning is
recorded, if at all, in a free-text note.

ConsentGate puts an AI Hub agent in that seat and then **does not let it act alone**.
The agent reads the consent artefacts and recommends a disposition with citations.
A deterministic policy gate verifies every citation as a literal substring of the
document it claims, re-checks the governing rules, and either accepts the
recommendation, overrides it, or escalates to a human. Only then does the
Interoperability production redact the message and route it.

> The agent proposes. The gate disposes. Nothing is disclosed on the model's word alone.

Triage asks *what went wrong with this message*. This asks *what may leave the
building* - a question with a legal answer, a named recipient, and an audit
obligation attached. That is why the model is not allowed the last word.

## What it does

```
   data/in/*.hl7
        │   HL7 v2.5.1 ORU^R01
        ▼
  EnsLib.File.PassthroughService
        │
        ▼
  ConsentGate.BP.Disclosure ──────────────────────────────┐
        │                                                  │
        │  1. read OBX codes, map to consent categories    │
        │  2. ask the agent for a recommendation           │
        │  3. run the deterministic gate                   │
        │  4. redact / route / audit                       │
        │                                                  │
        ├──► ConsentGate.Agent.ConsentAgent (%AI.Agent)   │
        │      tools: GetConsentDocuments                  │
        │             GetStructuredConsents                │
        │             GetRequestorProfile                  │
        │      returns strict JSON + verbatim quotes       │
        │                                                  │
        ├──► ConsentGate.Policy.Gate                      │
        │      · quote must be a substring of the document │
        │      · later revocation beats earlier consent    │
        │      · SUBSTANCE_USE needs a 42 CFR Part 2 form  │
        │      · DENIED / expired categories are withheld  │
        │      · low confidence or no evidence → escalate  │
        │                                                  ▼
        ├──► data/out/released_<msgid>.hl7   (RELEASE / REDACT)
        ├──► data/out/escalated/*.hl7      (human review)
        ├──► data/out/denied/*.hl7         (DENY)
        └──► ConsentGate_Data.Decision (audit row, every time)
```

## Quick start

### 1. Get the AI Hub image

AI Hub container images are distributed only through the InterSystems
[Early Access Program portal](https://evaluation.intersystems.com/Eval/early-access/AIHub);
they are not on a public registry. Download the **arm64** build for Apple Silicon
(or the matching build for your platform), then load it:

```bash
docker load -i ~/Downloads/irishealth_arm64-community-2027.1.0AI.109.0-docker.tar.gz
docker images | grep -i ai
```

This project was developed and tested against **build 109**
(`2027.1.0AI.109.0`). Set `IMAGE=` in the `Dockerfile` if the name printed by
`docker images` differs.

### 2. Configure a provider

```bash
cp .env.example .env
# put your key in .env: OPENAI_API_KEY=... or ANTHROPIC_API_KEY=...
```

The agent reads `CONSENTGATE_PROVIDER` (default `openai`) and the matching key.
Judges can use any provider the AI Hub supports; no key of ours is committed.

### 3. Run

```bash
docker compose up -d --build
```

Open the management portal at <http://localhost:52773/csp/sys/UtilHome.csp>
(`SuperUser` / `SYS`). The production starts automatically and watches `data/in`.

### 4. Watch a decision

```bash
cp data/samples/001_alvarez_clinic.hl7 data/in/
sleep 5
cat data/out/released_CG0001.hl7
```

The OBX for ethyl glucuronide comes out as `[WITHHELD: SUBSTANCE_USE]`; the
haemoglobin A1c and creatinine rows are untouched.

### No API key? Run the pipeline anyway

```bash
echo 'CONSENTGATE_REPLAY=1' >> .env
```

Every scenario still flows through the production, the gate and the audit table,
using a fixed recommendation per patient. Useful for judges who want to see the
Interoperability wiring before spending tokens, and for CI.

## Scenarios

| File | Patient | What the paperwork says | Expected outcome |
|---|---|---|---|
| `001_alvarez_clinic.hl7` | CG-0001 | Authorisation for diabetes/kidney results, **explicitly excludes** substance use | `REDACT` — GENERAL released, SUBSTANCE_USE withheld |
| `002_chen_clinic.hl7` | CG-0002 | Authorisation, then a **revocation** nine days later | `DENY` — gate overrides any release |
| `003_bello_clinic.hl7` | CG-0003 | Part 2 consent to this clinic only; **written HIV refusal** | `REDACT` — SUBSTANCE_USE and HIV withheld |
| `005_park_registry.hl7` | CG-0005 | Authorisation **expired in 2025**; public-health purpose | `ESCALATE` or `DENY` — no valid consent covers the request |

## The audit row

Every request produces exactly one row, whether or not data left the building.

```objectscript
zn "CONSENTGATE"
Set rs = ##class(ConsentGate.Data.Decision).Latest(10)
While rs.%Next() {
    Write rs.RequestID, " ", rs.MRN, " ", rs.Decision, " gate=", rs.GateResult, !
}
```

`Evidence` stores the quotes the agent relied on and whether each one was
verified against its source document. That is the difference between a decision
you can defend in an audit and a decision you cannot.

## Design notes

**Why not just ask the model?** Because a model that is right 95% of the time is
wrong on 5% of disclosures, and there is no way to tell which 5% from the output
alone. Citation verification turns an unverifiable claim into a checkable one:
if the sentence it cites is not in the document, the recommendation is not acted on.

**Why keep the agent's scope and the final scope separate?** The gate starts from
the agent's proposed release list, then removes anything a hard rule forbids. The
stored `GateResult` records whether that happened (`PASS` or `OVERRIDDEN`), so
override rates are measurable rather than invisible.

**Why parse HL7 as text instead of using the HL7 schema classes?** The community
IRIS for Health image does not ship the licensed v2 schema tables (`^EnsHL7` is
empty), so `EnsLib.HL7.Message.GetValueAt` returns nothing on that image. A gate
that decides what may be disclosed should not depend on a licensed schema library
being installed. The production still runs as a real Interoperability production;
only the segment parsing is ours.

**Why Interoperability rather than a sidecar service?** The redaction has to happen
to the actual HL7 message, with the production's retry, queueing and error
handling. A sidecar that returns JSON to a caller is a demo; this is the same
decision made inside the message path.

## Limitations

- Synthetic data only. No real PHI is used, generated or stored.
- The category map is a small LOINC subset for the demo; a real deployment would
  load a maintained value set.
- The gate encodes three rules, not a jurisdiction's complete consent model.
  It is a demonstration of the pattern — deterministic envelope, model inside —
  not a compliance product.
- Quote verification is a substring match. Documents that are OCR'd or reflowed
  from PDFs would need normalisation first.

## Layout

```
src/ConsentGate/
├── Agent/          ConsentAgent.cls, ConsentTools.cls
├── BP/             Disclosure.cls        (the business process)
├── Data/           Patient, ConsentDoc, StructuredConsent, Requestor, CodeMap, Decision
├── Policy/         Gate.cls              (deterministic rules and quote checks)
├── Production.cls
└── Setup.cls       (synthetic seed data)
data/
├── in/             drop HL7 files here
├── out/            released_*.hl7, escalated/, denied/
└── samples/        the four scenarios
```

## License

MIT.
