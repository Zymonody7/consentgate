/// Writes a read-only snapshot of the decision queue for the static console.
/// The static page is served by the container's web server without
/// authentication, so it can be opened by a reviewer with no IRIS login; the
/// authenticated console at /consentgate/ui/ remains the place where reviews
/// are recorded.
Class ConsentGate.Export.Snapshot Extends %RegisteredObject
{

ClassMethod Write() As %Status
{
    Set sc = $$$OK
    Try {
        Set dir = $System.Util.GetEnviron("CONSENTGATE_CONSOLE_DIR")
        If dir = "" Set dir = "/home/irisowner/dev/data/console"
        Do ##class(%File).CreateDirectoryChain(dir)
        Set decisions = ..Decisions()
        Set sc = ..WriteFile(dir_"/decisions.json", decisions)
        If $$$ISERR(sc) Quit
        Set sc = ..WriteFile(dir_"/stats.json", ..Stats())
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

ClassMethod WriteFile(path As %String, content As %String) As %Status
{
    Set file = ##class(%Stream.FileCharacter).%New()
    Set file.Filename = path
    Do file.Write(content)
    Quit file.%Save()
}

ClassMethod Decisions() As %String
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT TOP 50 ID, RequestID, MRN, RequestorOrg, PurposeOfUse, Decision, GateResult, Released, Withheld, Rationale, Evidence, Confidence, Model, LatencyMs, InjectionFlag, CreatedAt FROM ConsentGate_Data.Decision ORDER BY ID DESC")
    If $$$ISERR(sc) Quit "[]"
    Set rs = stmt.%Execute()

    // Latest review per decision.
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
    Quit out.%ToJSON()
}

ClassMethod Stats() As %String
{
    Set stats = {}
    Set stats.total = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision")
    Set stats.released = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'RELEASE'")
    Set stats.redacted = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'REDACT'")
    Set stats.denied = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'DENY'")
    Set stats.escalated = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'ESCALATE'")
    Set stats.pendingReview = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE Decision = 'ESCALATE' AND GateResult NOT LIKE 'REVIEWED%'")
    Set stats.injectionFlagged = ..Scalar("SELECT COUNT(*) FROM ConsentGate_Data.Decision WHERE InjectionFlag = 1")
    Quit stats.%ToJSON()
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

}
