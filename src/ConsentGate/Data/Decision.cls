/// The audit record. One row per disclosure request, whether the data
/// left the building or not. This is what makes the agent defensible:
/// the decision, the evidence it cited, and what the gate did with it.
Class ConsentGate.Data.Decision Extends %Persistent
{

Property RequestID As %String(MAXLEN = 64);

Property MRN As %String(MAXLEN = 32);

Property RequestorOrg As %String(MAXLEN = 64);

Property PurposeOfUse As %String(MAXLEN = 32);

/// RELEASE | REDACT | DENY | ESCALATE
Property Decision As %String(MAXLEN = 16);

Property Released As %String(MAXLEN = 512);

Property Withheld As %String(MAXLEN = 512);

Property Rationale As %String(MAXLEN = 4000);

/// JSON array of {docId, quote, verified}
Property Evidence As %String(MAXLEN = 4000);

Property Confidence As %String(MAXLEN = 16);

Property Model As %String(MAXLEN = 64);

Property LatencyMs As %Integer;

/// PASS | OVERRIDDEN | ESCALATED | UNPARSEABLE
Property GateResult As %String(MAXLEN = 32);

/// 1 when the inbound message or a document contained instruction-like text
Property InjectionFlag As %Integer;

Property CreatedAt As %String(MAXLEN = 32);

Index MRNIdx On MRN;

Index CreatedIdx On CreatedAt;

ClassMethod Latest(rows As %Integer = 20) As %SQL.StatementResult
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT TOP ? RequestID, MRN, RequestorOrg, Decision, Released, Withheld, GateResult, Confidence, LatencyMs, CreatedAt FROM ConsentGate_Data.Decision ORDER BY ID DESC")
    Quit stmt.%Execute(rows)
}

}
