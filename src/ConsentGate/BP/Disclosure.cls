/// The heart of the workflow: receives an HL7 ORU^R01 disclosure request,
/// asks the agent for a recommendation, runs it through the deterministic
/// gate, redacts what may not leave, routes the result, and audits everything.
///
/// The message is handled as HL7 v2 text rather than through the HL7 schema
/// classes: the community IRIS for Health image does not ship the v2 schema
/// tables, and a disclosure gate should not depend on a licensed schema
/// library to decide what may be released.
Class ConsentGate.BP.Disclosure Extends Ens.BusinessProcess
{

Method OnRequest(pRequest As Ens.StreamContainer, Output pResponse As Ens.Response) As %Status
{
    Set tSC = $$$OK
    Set started = $ZHOROLOG
    Try {
        Set text = ..ReadText(pRequest)
        If text = "" {
            Set tSC = $$$ERROR($$$GeneralError, "Empty message")
            Quit
        }

        // --- Envelope fields -------------------------------------------
        Set mrn = ""
        Set org = ""
        Set purpose = ""
        Set reqId = ""
        Set cr = $CHAR(13)
        Set n = $LENGTH(text, cr)
        Set i = 0
        While i < n {
            Set seg = $PIECE(text, cr, i + 1)
            Set segId = $PIECE(seg, "|", 1)
            If segId = "MSH" {
                Set org = $PIECE(seg, "|", 5)
                Set purpose = $PIECE(seg, "|", 6)
                Set reqId = $PIECE(seg, "|", 10)
            }
            If segId = "PID" Set mrn = $PIECE(seg, "|", 4)
            Set i = i + 1
        }

        If mrn = "" {
            Set tSC = $$$ERROR($$$GeneralError, "No patient identifier in PID-3")
            Quit
        }

        // --- Which consent categories does this message contain? -------
        Set catsSeen = ##class(%DynamicObject).%New()
        Set requested = ##class(%DynamicArray).%New()
        Set i = 0
        While i < n {
            Set seg = $PIECE(text, cr, i + 1)
            If $PIECE(seg, "|", 1) = "OBX" {
                Set code = $PIECE($PIECE(seg, "|", 4), "^", 1)
                Set cat = ##class(ConsentGate.Data.CodeMap).CategoryOf(code)
                If catsSeen.%Get(cat) = "" {
                    Do catsSeen.%Set(cat, 1)
                    Do requested.%Push(cat)
                }
            }
            Set i = i + 1
        }
        If requested.%Size() = 0 Do requested.%Push("GENERAL")

        // --- Ask the agent ---------------------------------------------
        Set agentRaw = ..RunAgent(mrn, org, purpose, requested)

        // --- Deterministic gate ----------------------------------------
        Set verdict = ##class(ConsentGate.Policy.Gate).Apply(mrn, org, requested, agentRaw)
        Set decision = verdict.decision

        // --- Record before acting; the audit trail is not optional -----
        Set rec = ##class(ConsentGate.Data.Decision).%New()
        Set rec.RequestID = reqId
        Set rec.MRN = mrn
        Set rec.RequestorOrg = org
        Set rec.PurposeOfUse = purpose
        Set rec.Decision = decision
        Set rec.Released = verdict.release.%ToJSON()
        Set rec.Withheld = verdict.withhold.%ToJSON()
        Set rec.Rationale = verdict.rationale
        Set rec.Evidence = verdict.evidence.%ToJSON()
        Set rec.Confidence = verdict.confidence
        Set rec.Model = $System.Util.GetEnviron("CONSENTGATE_MODEL")
        Set rec.GateResult = verdict.gate
        Set rec.LatencyMs = ($ZHOROLOG - started) * 1000 \ 1
        Set rec.CreatedAt = $ZDATE($HOROLOG, 3)_" "_$ZTIME($PIECE($HOROLOG, ",", 2), 1)
        Do rec.%Save()

        $$$LOGINFO("ConsentGate "_reqId_" mrn="_mrn_" decision="_decision_" gate="_verdict.gate)

        // --- Apply the decision to the message -------------------------
        Set outText = text
        If decision = "REDACT" {
            Set outText = ..RedactText(text, verdict.withhold)
        }

        // --- Route ------------------------------------------------------
        Set out = ##class(Ens.StreamContainer).%New()
        Set out.Stream = ##class(%Stream.GlobalCharacter).%New()
        Do out.Stream.Write(outText)
        Do out.Attributes.SetAt(reqId_".hl7", "Filename")

        Set target = "Archive"
        If decision = "ESCALATE" Set target = "Escalate"
        If decision = "DENY" Set target = "Deny"
        Set tSC = ..SendRequestSync(target, out, .pResponse)
    } Catch ex {
        Set tSC = ex.AsStatus()
        $$$LOGERROR("ConsentGate failed: "_$System.Status.GetErrorText(tSC))
    }
    Quit tSC
}

ClassMethod ReadText(pRequest As Ens.StreamContainer) As %String
{
    Set stream = pRequest.Stream
    If '$IsObject(stream) Quit ""
    Do stream.Rewind()
    Quit stream.Read(stream.Size)
}

/// Blank the value of every observation whose category may not be disclosed.
/// The segment stays, so the recipient can see that something was withheld.
ClassMethod RedactText(text As %String, withhold As %DynamicArray) As %String
{
    Set cr = $CHAR(13)
    Set n = $LENGTH(text, cr)
    Set out = ""
    Set i = 0
    While i < n {
        Set seg = $PIECE(text, cr, i + 1)
        If $PIECE(seg, "|", 1) = "OBX" {
            Set code = $PIECE($PIECE(seg, "|", 4), "^", 1)
            Set cat = ##class(ConsentGate.Data.CodeMap).CategoryOf(code)
            If ##class(ConsentGate.Policy.Gate).InArray(withhold, cat) {
                Set seg = $PIECE(seg, "|", 1, 5) _ "|" _ "[WITHHELD: "_cat_"]" _ "|" _ $PIECE(seg, "|", 7, 999)
            }
        }
        Set out = out _ seg
        If (i + 1) < n Set out = out _ cr
        Set i = i + 1
    }
    Quit out
}

ClassMethod RunAgent(mrn As %String, org As %String, purpose As %String, requested As %DynamicArray) As %String
{
    If $System.Util.GetEnviron("CONSENTGATE_REPLAY") = "1" {
        Quit ..ReplayResponse(mrn)
    }

    Set prompt = "Disclosure request."_$C(10)
        _ "Patient MRN: "_mrn_$C(10)
        _ "Requesting organisation: "_org_$C(10)
        _ "Declared purpose of use: "_purpose_$C(10)
        _ "Observation categories present in this message: "_requested.%ToJSON()_$C(10)
        _ "Decide what may be released. Cite the exact sentence you relied on."

    Set agent = ##class(ConsentGate.Agent.ConsentAgent).%New()
    Set sc = agent.%Init()
    If $$$ISERR(sc) {
        $$$LOGERROR("Agent init failed: "_$System.Status.GetErrorText(sc))
        Quit ""
    }
    Set session = agent.CreateSession({"max_iterations": 6})
    Set resp = agent.Chat(session, prompt)
    Quit resp.Content
}

/// Deterministic stand-in used when no API key is available (CONSENTGATE_REPLAY=1).
/// Quotes below are copied verbatim from the seeded documents.
ClassMethod ReplayResponse(mrn As %String) As %String
{
    If mrn = "CG-0001" {
        Quit {"decision":"REDACT","release":["GENERAL"],"withhold":["SUBSTANCE_USE"],"evidence":[{"docId":1,"quote":"This authorization does not extend to records of substance use disorder treatment"}],"rationale":"Authorisation covers diabetes and kidney results only; substance use records are expressly excluded.","confidence":0.93}.%ToJSON()
    }
    If mrn = "CG-0002" {
        Quit {"decision":"DENY","release":[],"withhold":["GENERAL"],"evidence":[{"docId":3,"quote":"revoke the authorization I signed on 2026-09-14"}],"rationale":"The most recent document revokes the prior authorisation.","confidence":0.95}.%ToJSON()
    }
    If mrn = "CG-0003" {
        Quit {"decision":"REDACT","release":["GENERAL"],"withhold":["HIV"],"evidence":[{"docId":5,"quote":"declined, in writing, the release of HIV-related laboratory results"}],"rationale":"Patient declined HIV disclosure; other results are permitted.","confidence":0.91}.%ToJSON()
    }
    Quit {"decision":"ESCALATE","release":[],"withhold":[],"evidence":[],"rationale":"No usable evidence in replay mode.","confidence":0.2}.%ToJSON()
}

}
