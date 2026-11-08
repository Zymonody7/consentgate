/// Deterministic decision layer: the model never chooses, it only reads.
///
/// The agent's job is to extract findings from consent documents - each finding
/// names a category, an effect, a recipient, a validity date and the verbatim
/// sentence that supports it. This class turns those findings into a decision:
///
///   1. every quote must literally appear in the document it cites
///   2. the quote must also contain language that speaks to that category
///   3. a finding whose recipient or validity does not cover this request is void
///   4. a later revocation voids every grant
///   5. anything the model did not affirmatively establish is withheld
///
/// The model's own "decision" field, if it sends one, is ignored entirely.
Class ConsentGate.Policy.Gate Extends %RegisteredObject
{

ClassMethod Apply(mrn As %String, requestorOrg As %String, requested As %DynamicArray, agentRaw As %String) As %DynamicObject
{
    Set result = {}
    Set result.notes = []
    Set result.evidence = []
    Set result.release = []
    Set result.withhold = []
    Set result.decision = "ESCALATE"
    Set result.gate = "PASS"
    Set result.rationale = ""
    Set result.confidence = 0

    // --- 1. Parse ------------------------------------------------------
    // Tolerate prose or a markdown fence around the JSON object.
    Set p1 = $FIND(agentRaw, "{")
    If p1 > 0 {
        Set p2 = $LENGTH(agentRaw) - $FIND($REVERSE(agentRaw), "}") + 2
        If (p2 > 0) && (p2 >= p1) Set agentRaw = $EXTRACT(agentRaw, p1 - 1, p2)
    }
    Set parsed = ""
    Try {
        Set parsed = ##class(%DynamicObject).%FromJSON(agentRaw)
    } Catch {
        Set parsed = ""
    }
    If '$IsObject(parsed) {
        Set result.gate = "UNPARSEABLE"
        Do result.notes.%Push("Agent output was not valid JSON; escalated without acting on it.")
        Quit result
    }

    Set result.rationale = parsed.rationale
    Set result.confidence = +parsed.confidence

    Set findings = parsed.findings
    If '$IsObject(findings) {
        Do result.notes.%Push("Agent returned no findings array; nothing can be established.")
        Set result.gate = "OVERRIDDEN"
        Quit result
    }

    // --- 2. Verify each finding ----------------------------------------
    // Latest instrument wins per category. Two findings dated the same day that
    // disagree are a real contradiction and escalate; a grant followed by a
    // later denial is simply an override.
    Set latestEff = {}
    Set latestDate = {}
    Set verifiedCount = 0
    Set conflicted = 0
    Set ocrProtected = 0
    Set today = $ZDATE($HOROLOG, 3)

    Set i = 0
    While i < findings.%Size() {
        Set f = findings.%Get(i)
        Set docId = f.docId
        Set category = $ZCONVERT(f.%Get("category"), "U")
        Set effect = $ZCONVERT(f.%Get("effect"), "U")
        Set quote = f.%Get("quote")
        Set recipient = f.%Get("recipient")
        Set validUntil = f.%Get("validUntil")

        Set ok = 0
        Set why = ""
        Set docDate = ""

        If (docId = "") || (quote = "") || (category = "") {
            Set why = "incomplete finding"
        } Else {
            Set doc = ##class(ConsentGate.Data.ConsentDoc).%OpenId(docId)
            If '$IsObject(doc) {
                Set why = "document "_docId_" does not exist"
            } ElseIf $FIND(doc.Body, quote) = 0 {
                Set why = "quote not found verbatim in document "_docId
            } ElseIf '..QuoteSpeaksTo(quote, category) {
                Set why = "quote does not mention anything about "_category
            } ElseIf (validUntil '= "") && (validUntil < today) {
                Set why = "instrument expired on "_validUntil
            } ElseIf (recipient '= "") && ($ZCONVERT(recipient, "U") '= $ZCONVERT(requestorOrg, "U")) {
                Set why = "instrument names a different recipient ("_recipient_")"
            } Else {
                Set ok = 1
                Set docDate = doc.ReceivedOn
            }
        }

        If ok {
            Set verifiedCount = verifiedCount + 1
            Do result.evidence.%Push({"docId": (docId), "category": (category), "effect": (effect), "quote": (quote), "verified": (1), "docType": (doc.DocType), "provenance": (doc.Provenance)})
            If (effect = "GRANT") && ($ZCONVERT(doc.Provenance, "U") = "OCR") && ..IsProtected(category) Set ocrProtected = 1

            Set prior = latestDate.%Get(category)
            If (prior = "") || (docDate > prior) {
                Do latestDate.%Set(category, docDate)
                Do latestEff.%Set(category, effect)
            } ElseIf (docDate = prior) && (effect '= latestEff.%Get(category)) {
                Set conflicted = 1
            }
        } Else {
            Do result.notes.%Push(category_" finding rejected: "_why)
            Do result.evidence.%Push({"docId": (docId), "category": (category), "effect": (effect), "quote": (quote), "verified": (0), "reason": (why)})
            Set result.gate = "OVERRIDDEN"
        }
        Set i = i + 1
    }

    If verifiedCount = 0 {
        Do result.notes.%Push("No finding survived verification; escalated.")
        Set result.gate = "OVERRIDDEN"
        Quit result
    }

    If conflicted {
        Do result.notes.%Push("Two findings dated the same day disagree; escalated.")
        Set result.gate = "OVERRIDDEN"
        Quit result
    }

    // An OCR transcript is machine-derived: it may be right, but it is not the
    // paper. Protected categories do not leave on a machine transcript alone.
    If ocrProtected {
        Do result.notes.%Push("A protected category was granted from an OCR transcript; escalated for human verification of the scan.")
        Set result.gate = "OVERRIDDEN"
        Set result.decision = "ESCALATE"
        Quit result
    }

    // --- 3. Hard rules ---------------------------------------------------
    // A revocation that arrives after the latest authorisation voids release.
    If ..LatestDocIsRevocation(mrn) {
        Do result.notes.%Push("A revocation is the most recent consent document; all release is denied.")
        Set result.gate = "OVERRIDDEN"
        Set result.decision = "DENY"
        Set i = 0
        While i < requested.%Size() {
            Do result.withhold.%Push(requested.%Get(i))
            Set i = i + 1
        }
        Quit result
    }

    // 42 CFR Part 2: substance use records need a Part 2 consent, whatever
    // the extraction says.
    If (latestEff.%Get("SUBSTANCE_USE") = "GRANT") && '..HasDocType(mrn, "PART2_CONSENT") {
        Do latestEff.%Set("SUBSTANCE_USE", "DENY")
        Do result.notes.%Push("SUBSTANCE_USE withheld by gate: no 42 CFR Part 2 consent on file.")
        Set result.gate = "OVERRIDDEN"
    }

    // --- 4. Decide from the permitted set, not from the model's prose ----
    Set i = 0
    While i < requested.%Size() {
        Set cat = requested.%Get(i)
        If latestEff.%Get(cat) = "GRANT" {
            Do result.release.%Push(cat)
        } Else {
            Do result.withhold.%Push(cat)
        }
        Set i = i + 1
    }

    Set nRel = result.release.%Size()
    If nRel = requested.%Size() {
        Set result.decision = "RELEASE"
    } ElseIf nRel = 0 {
        Set result.decision = "DENY"
    } Else {
        Set result.decision = "REDACT"
    }

    Quit result
}

/// Does the quoted sentence contain language that actually speaks to this
/// category? A real sentence can be copied out of a document and still be
/// irrelevant to the category it is used to justify.
ClassMethod QuoteSpeaksTo(quote As %String, category As %String) As %Boolean
{
    Set q = $ZCONVERT(quote, "U")
    If category = "SUBSTANCE_USE" Quit ..Mentions(q, "SUBSTANCE,42 CFR,PART 2,DRUG,ALCOHOL,CHEMICAL DEPENDENCY")
    If category = "MENTAL_HEALTH" Quit ..Mentions(q, "MENTAL,PSYCHIATRIC,PSYCHOLOG,BEHAVIORAL,PHQ")
    If category = "HIV" Quit ..Mentions(q, "HIV,AIDS,ANTIRETROVIRAL")
    If category = "GENETIC" Quit ..Mentions(q, "GENETIC,BRCA,GENOMIC")
    Quit ..Mentions(q, "AUTHORIZ,AUTHORIS,RELEASE,DISCLOS,CONSENT,PERMIT,LABORATORY RESULT")
}

ClassMethod IsProtected(category As %String) As %Boolean
{
    Quit (category = "SUBSTANCE_USE") || (category = "HIV") || (category = "GENETIC")
}

ClassMethod Mentions(text As %String, list As %String) As %Boolean
{
    Set found = 0
    Set n = $LENGTH(list, ",")
    Set i = 0
    While i < n {
        If $FIND(text, $PIECE(list, ",", i + 1)) > 0 Set found = 1
        Set i = i + 1
    }
    Quit found
}

ClassMethod HasDocType(mrn As %String, docType As %String) As %Boolean
{
    Set found = 0
    Set rs = ##class(ConsentGate.Data.ConsentDoc).ForMRN(mrn)
    While rs.%Next() {
        If rs.DocType = docType Set found = 1
    }
    Quit found
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

ClassMethod InArray(arr As %DynamicArray, value As %String) As %Boolean
{
    Set found = 0
    Set i = 0
    While i < arr.%Size() {
        If arr.%Get(i) = value Set found = 1
        Set i = i + 1
    }
    Quit found
}

}
