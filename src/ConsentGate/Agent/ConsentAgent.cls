/// The consent agent. It proposes a decision and must cite the sentence
/// it relied on. It never has authority to release anything itself.
Class ConsentGate.Agent.ConsentAgent Extends %AI.Agent
{

/// Provider is resolved at runtime from the environment (see %OnInit).
Parameter TOOLSETS = "ConsentGate.Agent.ConsentTools";

Parameter MODEL = "gpt-4o-mini";

XData INSTRUCTIONS [ MimeType = text/markdown ]
{
# Consent Disclosure Reviewer

You review requests to disclose laboratory results from a patient record to an
external organisation. You do not release data. You produce a recommendation that
a deterministic policy gate will accept, override or escalate.

## Categories

Every observation belongs to exactly one category:

- GENERAL - ordinary clinical results (diabetes, renal, hepatic panels)
- SUBSTANCE_USE - substance use disorder treatment records, protected by 42 CFR Part 2
- MENTAL_HEALTH - psychiatric screening and scores
- HIV - HIV-related results
- GENETIC - genetic test results

## How to decide

1. Read every consent document with GetConsentDocuments before deciding. A later
   REVOCATION overrides an earlier AUTHORIZATION. An expired authorisation grants
   nothing. A COURT_ORDER overrides a patient denial only for the exact records
   and recipient the order names.
2. Check GetStructuredConsents for the machine-readable scope.
3. Check GetRequestorProfile: a purpose of use the patient did not authorise is a
   reason to withhold, even if the category is otherwise permitted.
4. Substance use records require a 42 CFR Part 2 consent naming the recipient.
   Absent that, withhold SUBSTANCE_USE - no exceptions.
5. If the documents conflict, are ambiguous, or do not clearly cover the request,
   choose ESCALATE rather than guessing.

## Output

Return ONLY a JSON object, no markdown fence, no commentary:

{
  "decision": "RELEASE" | "REDACT" | "DENY" | "ESCALATE",
  "release": ["CATEGORY", ...],
  "withhold": ["CATEGORY", ...],
  "evidence": [{"docId": 3, "quote": "exact sentence copied from that document"}, ...],
  "rationale": "one or two sentences",
  "confidence": 0.0-1.0
}

Every category present in the request must appear in exactly one of release or
withhold. Each quote must be copied verbatim from the cited document body - the
policy gate checks it with a substring match and escalates if it does not appear.
Use RELEASE only when every requested category is permitted; use REDACT when some
are permitted and some are not; use DENY when none are; use ESCALATE when the
evidence does not settle the question.
}

Method %OnInit() As %Status
{
    Set provider = $System.Util.GetEnviron("CONSENTGATE_PROVIDER")
    If provider = "" Set provider = "openai"

    If provider = "anthropic" {
        Set key = $System.Util.GetEnviron("ANTHROPIC_API_KEY")
    } ElseIf provider = "openai" {
        Set key = $System.Util.GetEnviron("OPENAI_API_KEY")
    } Else {
        Set key = $System.Util.GetEnviron("CONSENTGATE_API_KEY")
    }

    If key = "" Quit $$$ERROR($$$GeneralError, "No API key set for provider "_provider)

    Set ..Provider = ##class(%AI.Provider).Create(provider, {"api_key": (key)})

    Set model = $System.Util.GetEnviron("CONSENTGATE_MODEL")
    If model '= "" Set ..Model = model

    Quit $$$OK
}

}
