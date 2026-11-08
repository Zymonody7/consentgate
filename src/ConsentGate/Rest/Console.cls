/// JSON API for the reviewer console.
///
/// GET  /decisions  the latest 50 audit rows with their review, if any
/// POST /review     record a reviewer decision and update the gate result
/// GET  /stats      counts for the summary strip
Class ConsentGate.Rest.Console Extends %CSP.REST
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/decisions" Method="GET" Call="GetDecisions" />
<Route Url="/review" Method="POST" Call="PostReview" />
<Route Url="/stats" Method="GET" Call="GetStats" />
</Routes>
}

ClassMethod GetDecisions() As %Status
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT TOP 50 ID, RequestID, MRN, RequestorOrg, PurposeOfUse, Decision, GateResult, Released, Withheld, Rationale, Evidence, Confidence, Model, LatencyMs, InjectionFlag, CreatedAt FROM ConsentGate_Data.Decision ORDER BY ID DESC")
    If $$$ISERR(sc) {
        Do ..SendError("Could not prepare the decision query: "_$System.Status.GetErrorText(sc))
        Quit $$$OK
    }
    Set rs = stmt.%Execute()
    If rs.%SQLCODE < 0 {
        Do ..SendError("Could not read decisions. SQLCODE "_rs.%SQLCODE)
        Quit $$$OK
    }

    // Latest review per decision: rows are newest first, first seen wins.
    Set reviews = {}
    Set rstmt = ##class(%SQL.Statement).%New()
    Set rsc = rstmt.%Prepare("SELECT DecisionId, Action, Reviewer, Note, CreatedAt FROM ConsentGate_Data.Review ORDER BY ID DESC")
    If '$$$ISERR(rsc) {
        Set rrs = rstmt.%Execute()
        While rrs.%Next() {
            Set rid = +rrs.%GetData(1)
            If '$DATA(reviews(rid)) {
                Set rv = {}
                Set rv.action = rrs.%GetData(2)
                Set rv.reviewer = rrs.%GetData(3)
                Set rv.note = rrs.%GetData(4)
                Set rv.createdAt = rrs.%GetData(5)
                Set reviews(rid) = rv
            }
        }
    }

    Set out = []
    While rs.%Next() {
        Set row = {}
        Set row.id = +rs.%GetData(1)
        Set row.requestId = rs.%GetData(2)
        Set row.mrn = rs.%GetData(3)
        Set row.requestorOrg = rs.%GetData(4)
        Set row.purposeOfUse = rs.%GetData(5)
        Set row.decision = rs.%GetData(6)
        Set row.gateResult = rs.%GetData(7)
        Set row.released = ..ParseArray(rs.%GetData(8))
        Set row.withheld = ..ParseArray(rs.%GetData(9))
        Set row.rationale = rs.%GetData(10)
        Set row.evidence = ..ParseArray(rs.%GetData(11))
        Set row.confidence = rs.%GetData(12)
        Set row.model = rs.%GetData(13)
        Set row.latencyMs = +rs.%GetData(14)
        Set row.injectionFlag = +rs.%GetData(15)
        Set row.createdAt = rs.%GetData(16)
        Set did = +rs.%GetData(1)
        If $DATA(reviews(did)) {
            Do row.%Set("review", reviews(did))
        } Else {
            Do row.%Set("review", "", "null")
        }
        Do out.%Push(row)
    }

    Do ..WriteJSON(out.%ToJSON())
    Quit $$$OK
}

/// Record a reviewer action. APPROVE moves the gate result to REVIEWED_RELEASE,
/// UPHOLD to REVIEWED_UPHOLD. The original disposition stays on the row.
ClassMethod PostReview() As %Status
{
    Set body = ""
    If $ISOBJECT(%request.Content) {
        Set body = %request.Content.Read()
    }
    If body = "" {
        Do ..SendError("Request body is empty.")
        Quit $$$OK
    }

    Set req = ##class(%DynamicAbstractObject).%FromJSON(body)
    Set decisionId = +req.%Get("decisionId")
    Set action = $ZCONVERT("" _ req.%Get("action"), "U")
    Set reviewer = $ZSTRIP("" _ req.%Get("reviewer"), "<>W")
    Set note = "" _ req.%Get("note")

    If (action '= "APPROVE") && (action '= "UPHOLD") {
        Do ..SendError("action must be APPROVE or UPHOLD.")
        Quit $$$OK
    }
    If decisionId = 0 {
        Do ..SendError("decisionId is required.")
        Quit $$$OK
    }
    If $LENGTH(reviewer) > 64 Set reviewer = $EXTRACT(reviewer, 1, 64)
    If $LENGTH(note) > 512 Set note = $EXTRACT(note, 1, 512)

    Set decision = ##class(ConsentGate.Data.Decision).%OpenId(decisionId)
    If '$ISOBJECT(decision) {
        Do ..SendError("decision "_decisionId_" was not found.")
        Quit $$$OK
    }

    If action = "APPROVE" {
        Set decision.GateResult = "REVIEWED_RELEASE"
    } Else {
        Set decision.GateResult = "REVIEWED_UPHOLD"
    }
    Set sc = decision.%Save()
    If $$$ISERR(sc) {
        Do ..SendError("Could not update the decision: "_$System.Status.GetErrorText(sc))
        Quit $$$OK
    }

    Set rev = ##class(ConsentGate.Data.Review).%New()
    Set rev.DecisionId = decisionId
    Set rev.Action = action
    Set rev.Reviewer = reviewer
    Set rev.Note = note
    Set rev.CreatedAt = $ZDATE($HOROLOG, 3)_" "_$ZTIME($PIECE($HOROLOG, ",", 2), 1)
    Set sc = rev.%Save()
    If $$$ISERR(sc) {
        Do ..SendError("Could not record the review: "_$System.Status.GetErrorText(sc))
        Quit $$$OK
    }

    Do ..WriteJSON("{""ok"":true}")
    Quit $$$OK
}

ClassMethod GetStats() As %Status
{
    Set stats = {}
    Set stats.total = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision")
    Set stats.released = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'RELEASE'")
    Set stats.redacted = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'REDACT'")
    Set stats.denied = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'DENY'")
    Set stats.escalated = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'ESCALATE'")
    Set stats.pendingReview = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'ESCALATE' AND GateResult NOT LIKE 'REVIEWED%'")
    Set stats.injectionFlagged = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE InjectionFlag = 1")
    Do ..WriteJSON(stats.%ToJSON())
    Quit $$$OK
}

ClassMethod Scalar(sql As %String) As %Integer
{
    Set n = 0
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)
    If '$$$ISERR(sc) {
        Set rs = stmt.%Execute()
        If rs.%Next() Set n = +rs.%GetData(1)
    }
    Quit n
}

ClassMethod ParseArray(value As %String) As %DynamicArray
{
    Set arr = []
    If value '= "" {
        Try {
            Set parsed = ##class(%DynamicAbstractObject).%FromJSON(value)
            If $ISOBJECT(parsed) Set arr = parsed
        } Catch {
            Set arr = []
        }
    }
    Quit arr
}

ClassMethod WriteJSON(json As %String) As %Status
{
    Set %response.ContentType = "application/json"
    Write json
    Quit $$$OK
}

ClassMethod SendError(message As %String) As %Status
{
    Set %response.Status = 500
    Set %response.ContentType = "application/json"
    Set err = {}
    Set err.ok = 0
    Set err.error = message
    Write err.%ToJSON()
    Quit $$$OK
}

}
