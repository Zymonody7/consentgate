/// Deterministic policy gate. The agent proposes; this class disposes.
///
/// The gate re-checks three things the model cannot be trusted with:
///   1. that every quote it cited actually appears in the document it cites
///   2. that a later revocation really overrides an earlier authorisation
///   3. that protected categories (42 CFR Part 2, denied HIV/genetic) are not
///      released on the strength of an authorisation that does not cover them
///
/// Anything it cannot settle is escalated to a human, never guessed.
Class ConsentGate.Policy.Gate Extends %RegisteredObject
{

ClassMethod Apply(mrn As %String, requestorOrg As %String, requested As %DynamicArray, agentRaw As %String) As %DynamicObject
{
    Set result = {}
    Set result.rationale = ""
    Set result.confidence = 0
    Set result.evidence = []
    Set result.notes = []
    Set result.decision = "ESCALATE"
    Set result.release = []
    Set result.withhold = []
    Set result.gate = "PASS"

    // --- 1. Parse ------------------------------------------------------
    Set parsed = ""
    Try {
        Set parsed = ##class(%DynamicAbstractObject).%FromJSON(agentRaw)
    } Catch {
        Set parsed = ""
    }
    If '$IsObject(parsed) {
        Set result.gate = "UNPARSEABLE"
        Do result.notes.%Push("Agent output was not valid JSON; escalated without acting on it.")
        Quit result
    }
    If (parsed.decision = "") || ('..IsKnownDecision(parsed.decision)) {
        Set result.gate = "UNPARSEABLE"
        Do result.notes.%Push("Agent returned an unknown decision value; escalated.")
        Quit result
    }

    Set result.rationale = parsed.rationale
    Set result.confidence = +parsed.confidence

    // --- 2. Verify every cited quote against its document --------------
    Set evidence = parsed.evidence
    Set verified = []
    Set evidenceOk = 1
    If $IsObject(evidence) {
        Set i = 0
        While (i < evidence.%Size()) && evidenceOk {
            Set item = evidence.%Get(i)
            Set docId = item.docId
            Set quote = item.quote
            Set ok = 0
            If (docId '= "") && (quote '= "") {
                Set doc = ##class(ConsentGate.Data.ConsentDoc).%OpenId(docId)
                If $IsObject(doc) {
                    If $FIND(doc.Body, quote) > 0 Set ok = 1
                }
            }
            If ok {
                Do verified.%Push({"docId": (docId), "quote": (quote), "verified": (1)})
            } Else {
                Set evidenceOk = 0
                Do result.notes.%Push("Cited quote not found in document "_docId_"; escalated rather than trust it.")
            }
            Set i = i + 1
        }
    }
    Set result.evidence = verified

    If 'evidenceOk {
        Set result.gate = "OVERRIDDEN"
        Set result.decision = "ESCALATE"
        Quit result
    }

    // A decision with no evidence is a guess.
    If (result.decision '= "ESCALATE") && '(..HasVerified(verified)) {
        Do result.notes.%Push("No verified evidence was cited; escalated.")
        Set result.gate = "OVERRIDDEN"
        Set result.decision = "ESCALATE"
    }

    // Low confidence is not a decision either.
    Set minConf = +$System.Util.GetEnviron("CONSENTGATE_MIN_CONFIDENCE")
    If minConf = 0 Set minConf = 0.6
    If (result.decision '= "ESCALATE") && (result.confidence < minConf) {
        Do result.notes.%Push("Agent confidence below "_minConf_"; escalated.")
        Set result.gate = "OVERRIDDEN"
        Set result.decision = "ESCALATE"
    }

    If result.decision = "ESCALATE" {
        Quit result
    }

    // --- 3. Start from the agent's scope, then correct it --------------
    Set release = []
    Set withhold = []
    If $IsObject(parsed.release) {
        Set i = 0
        While i < parsed.release.%Size() {
            Do release.%Push(parsed.release.%Get(i))
            Set i = i + 1
        }
    }

    // Rule A: a later revocation beats an earlier authorisation.
    If ..LatestDocIsRevocation(mrn) {
        Do result.notes.%Push("A revocation is the most recent consent document; all release is denied.")
        Set result.gate = "OVERRIDDEN"
        Set release = []
        Set withhold = ..CopyArray(requested)
        Set result.decision = "DENY"
        Set result.release = release
        Set result.withhold = withhold
        Quit result
    }

    // Rule B: protected categories need their own instrument.
    Set i = 0
    While i < requested.%Size() {
        Set cat = requested.%Get(i)
        Set reason = ..CategoryBlocker(mrn, cat)
        If reason '= "" {
            If ..InArray(release, cat) {
                Set release = ..Remove(release, cat)
                Do result.notes.%Push(cat_" withheld by gate: "_reason)
                Set result.gate = "OVERRIDDEN"
            }
            If '..InArray(withhold, cat) Do withhold.%Push(cat)
        } ElseIf '..InArray(release, cat) && '..InArray(withhold, cat) {
            Do withhold.%Push(cat)
        }
        Set i = i + 1
    }

    Set result.release = release
    Set result.withhold = withhold

    // --- 4. Recompute the verdict from the scope, not the prose --------
    Set nRel = release.%Size()
    Set nReq = requested.%Size()
    If nRel = nReq {
        Set result.decision = "RELEASE"
    } ElseIf nRel = 0 {
        Set result.decision = "DENY"
    } Else {
        Set result.decision = "REDACT"
    }

    Quit result
}

ClassMethod CategoryBlocker(mrn As %String, category As %String) As %String
{
    // 42 CFR Part 2: substance use records need a Part 2 consent on file.
    If category = "SUBSTANCE_USE" {
        If '..HasDocType(mrn, "PART2_CONSENT") Quit "no 42 CFR Part 2 consent on file"
        Quit ""
    }

    // A structured DENIED row blocks the category unless a court order names it.
    Set stmt = ##class(%SQL.Statement).%New()
    Set q = "SELECT Status, ValidTo FROM ConsentGate_Data.StructuredConsent WHERE MRN = ? AND Category = ?"
    Do stmt.%Prepare(q)
    Set rs = stmt.%Execute(mrn, category)
    If rs.%Next() {
        If rs.Status = "DENIED" {
            If '..HasDocType(mrn, "COURT_ORDER") Quit "category is marked DENIED in the structured consent"
        }
        If (rs.ValidTo '= "") && (rs.ValidTo < $ZDATE($HOROLOG, 3)) {
            Quit "consent for this category expired on "_rs.ValidTo
        }
    }
    Quit ""
}

ClassMethod HasDocType(mrn As %String, docType As %String) As %Boolean
{
    Set rs = ##class(ConsentGate.Data.ConsentDoc).ForMRN(mrn)
    While rs.%Next() {
        If rs.DocType = docType Quit 1
    }
    Quit 0
}

ClassMethod LatestDocIsRevocation(mrn As %String) As %Boolean
{
    Set latestType = ""
    Set latestDate = ""
    Set rs = ##class(ConsentGate.Data.ConsentDoc).ForMRN(mrn)
    While rs.%Next() {
        If rs.ReceivedOn >= latestDate {
            Set latestDate = rs.ReceivedOn
            Set latestType = rs.DocType
        }
    }
    Quit (latestType = "REVOCATION")
}

ClassMethod IsKnownDecision(v As %String) As %Boolean
{
    Quit (v = "RELEASE") || (v = "REDACT") || (v = "DENY") || (v = "ESCALATE")
}

ClassMethod HasVerified(verified As %DynamicArray) As %Boolean
{
    Set i = 0
    While i < verified.%Size() {
        If verified.%Get(i).verified = 1 Quit 1
        Set i = i + 1
    }
    Quit 0
}

ClassMethod InArray(arr As %DynamicArray, value As %String) As %Boolean
{
    Set i = 0
    While i < arr.%Size() {
        If arr.%Get(i) = value Quit 1
        Set i = i + 1
    }
    Quit 0
}

ClassMethod Remove(arr As %DynamicArray, value As %String) As %DynamicArray
{
    Set out = []
    Set i = 0
    While i < arr.%Size() {
        If arr.%Get(i) '= value Do out.%Push(arr.%Get(i))
        Set i = i + 1
    }
    Quit out
}

ClassMethod CopyArray(arr As %DynamicArray) As %DynamicArray
{
    Set out = []
    Set i = 0
    While i < arr.%Size() {
        Do out.%Push(arr.%Get(i))
        Set i = i + 1
    }
    Quit out
}

}
