/// The heart of the workflow: receives an HL7 ORU^R01 disclosure request,
/// asks the agent for a recommendation, runs it through the deterministic
/// gate, redacts what may not leave, routes the result, and audits everything.
Class ConsentGate.BP.Disclosure Extends Ens.BusinessProcess
{

Method OnRequest(pRequest As EnsLib.HL7.Message, Output pResponse As Ens.Response) As %Status
{
    Set tSC = $$$OK
    Set started = $ZHOROLOG
    Try {
        Set mrn = pRequest.GetValueAt("PID:3.1")
        Set org = pRequest.GetValueAt("MSH:5")
        Set purpose = pRequest.GetValueAt("MSH:6")
        Set reqId = pRequest.GetValueAt("MSH:10")

        If mrn = "" {
            Set tSC = $$$ERROR($$$GeneralError, "No patient identifier in PID:3")
            Quit
        }

        // --- Which consent categories does this message contain? -------
        Set catsSeen = {}
        Set requested = []
        Set i = 1
        Set code = "x"
        While (i <= 500) && (code '= "") {
            Set code = pRequest.GetValueAt("OBXgrp("_i_"):OBX:3.1")
            If code '= "" {
                Set cat = ##class(ConsentGate.Data.CodeMap).CategoryOf(code)
                If catsSeen.%Get(cat) = "" {
                    Do catsSeen.%Set(cat, 1)
                    Do requested.%Push(cat)
                }
                Set i = i + 1
            }
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
        Set rec.CreatedAt = $ZDATE($HOROLOG, 3)_" "_$ZTIME($PIECE($HOROLOG,",",2), 1)
        Do rec.%Save()

        $$$LOGINFO("ConsentGate "_reqId_" mrn="_mrn_" decision="_decision_" gate="_verdict.gate)

        // --- Apply the decision to the message -------------------------
        If decision = "REDACT" {
            Do ..Redact(pRequest, verdict.withhold)
        }

        // --- Route ------------------------------------------------------
        Set out = ""
        If decision = "ESCALATE" {
            Set tSC = ..SendRequestSync("Escalate", pRequest, .out)
        } ElseIf decision = "DENY" {
            Set tSC = ..SendRequestSync("Deny", pRequest, .out)
        } Else {
            Set tSC = ..SendRequestSync("Archive", pRequest, .out)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        $$$LOGERROR("ConsentGate failed: "_$System.Status.GetErrorText(tSC))
    }
    Quit tSC
}

/// Blank the value of every observation whose category may not be disclosed.
/// The segment itself stays so the recipient can see that something was withheld.
ClassMethod Redact(msg As EnsLib.HL7.Message, withhold As %DynamicArray) As %Status
{
    Set i = 1
    Set code = "x"
    While (i <= 500) && (code '= "") {
        Set code = msg.GetValueAt("OBXgrp("_i_"):OBX:3.1")
        If code '= "" {
            Set cat = ##class(ConsentGate.Data.CodeMap).CategoryOf(code)
            If ##class(ConsentGate.Policy.Gate).InArray(withhold, cat) {
                Do msg.SetValueAt("[WITHHELD: "_cat_"]", "OBXgrp("_i_"):OBX:5.1")
            }
            Set i = i + 1
        }
    }
    Quit $$$OK
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
