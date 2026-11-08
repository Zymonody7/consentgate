/// Machine-readable consent scope, for the categories that have one.
/// Kept separate from ConsentDoc so the agent can be shown both the
/// structured truth and the unstructured text that overrides it.
Class ConsentGate.Data.StructuredConsent Extends %Persistent
{

Property MRN As %String(MAXLEN = 32) [ Required ];

Property Category As %String(MAXLEN = 32) [ Required ];

/// GRANTED | DENIED
Property Status As %String(MAXLEN = 16);

Property ValidFrom As %String(MAXLEN = 10);

Property ValidTo As %String(MAXLEN = 10);

Property SourceDocId As %String(MAXLEN = 32);

Index MRNIdx On MRN;

ClassMethod ForMRN(mrn As %String) As %SQL.StatementResult
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT Category, Status, ValidFrom, ValidTo FROM ConsentGate_Data.StructuredConsent WHERE MRN = ?")
    Quit stmt.%Execute(mrn)
}

}
